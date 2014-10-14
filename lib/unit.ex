defmodule Genom.Unit do
	
	use ExActor.GenServer, export: :GenomUnit
	require Logger
	@timeout :timer.minutes(1)

	defmodule MasterState do
		@derive [HashUtils]
		defstruct my_info: %Genom.AppInfo{}, slaves_info: %{}, other_hosts: [], stamp: 0
	end
	defmodule SlaveState do
		@derive [HashUtils]
		defstruct my_info: %Genom.AppInfo{}, stamp: 0
	end

	definit do
		{
			:ok, 
			( create_state
				|> main_slave_handler
					|> update_stamp  ),
			@timeout
		}
	end

	defcast add_hostinfo(host_info = %Genom.HostInfo{}), state: state = %MasterState{stamp: mystamp} do
		{
			:noreply,
			HashUtils.modify(state, [:other_hosts], 
						fn(hosts_list) ->
							merge_incoming_hostinfo(hosts_list, host_info)
						end ),
			calculate_timeout(mystamp)
		}
	end
	defcast add_slaveinfo(slave_info = %Genom.AppInfo{id: appid}), state: state = %MasterState{stamp: mystamp} do
		{
			:noreply,
			HashUtils.add(state, [:slaves_info, appid], slave_info),
			calculate_timeout(mystamp)
		}
	end

	definfo :timeout, state: state = %SlaveState{} do
		{
			:noreply,
			main_slave_handler(state),
			@timeout
		}
	end
	definfo :timeout, state: state = %MasterState{stamp: mystamp} do
		{
			:noreply,
			( main_master_handler(state) |> update_stamp ),
			@timeout
		}
	end

	#######################
	### init priv funcs ###
	#######################

	defp create_state do
		%SlaveState{ my_info: %Genom.AppInfo{ 
			id: Genom.Tinca.get(:my_id),
			name: Genom.Tinca.get(:my_app),
			role: :slave,
			status: :alive,
			modules_info: Genom.Tinca.get(:modules_info),
			port: Genom.Tinca.get(:my_port),
			stamp: Exutils.makestamp }}
	end
	defp become_master %SlaveState{ my_info: my_info = %Genom.AppInfo{} } do

		Genom.WebServer.start
		
		%MasterState{ 
			my_info: HashUtils.set(my_info, :role, :master),
			slaves_info: %{},
			other_hosts: Genom.Tinca.get(:hosts) 
							|> Enum.map(&create_host_struct/1) }
	end
	defp create_host_struct %Genom.Host{host: host, port: port, comment: comment} do
		%Genom.HostInfo{apps: %{}, host: host, port: port, stamp: 0, status: :dead, comment: comment }
	end

	##########################
	### refresh priv funcs ###
	##########################

	defp refresh_self state do
		state |> refresh_modules_info |> refresh_timestamp
	end
	defp refresh_modules_info(state) do
		HashUtils.set(state, [:my_info, :modules_info],
			Genom.Tinca.get(:modules_info))
	end
	defp refresh_timestamp(state) do
		HashUtils.set(state, [:my_info, :stamp],
			Exutils.makestamp)
	end

	#######################
	### else priv funcs ###
	#######################


	defp update_stamp(state) do
		HashUtils.set( state, :stamp, Exutils.makestamp )
	end

	defp calculate_timeout(stamp) when is_integer(stamp) do
		case (stamp + @timeout) - Exutils.makestamp do
			some when (some > 0) -> some
			some_else -> 	send(self, :timeout)
							0
		end
	end

	########################
	### slave priv funcs ###
	########################


	defp main_slave_handler(old_state) do
		state = refresh_self(old_state)
		case report_to_master(state) do
			:failed -> become_master(state) |> main_master_handler
			:ok -> state
		end
	end


	defp report_to_master( %SlaveState{my_info: my_info = %Genom.AppInfo{ port: my_port }} ) do
		case :erlang.term_to_binary(my_info)
				|> :base64.encode
					|>  try_report_to_master(my_port) do
			{:ok, _} -> :ok
			err -> 	Logger.warn "Genom.Unit : report to master failed, code is #{inspect err}"
					:failed
		end
	end
	defp try_report_to_master(my_info_bin, my_port) do
		Retry.run( %{sleep: 500, tries: 3}, 
			fn() -> 
				%HTTPoison.Response{status_code: 200, body: "ok"} = 
					HTTPoison.post("http://localhost:#{my_port}/internal",
									my_info_bin,
									[{"Content-Type","text/plain"}])
			end )
	end

	#########################
	### master priv funcs ###
	#########################

	@slave_death_timeout :timer.minutes(3)
	@host_death_timeout :timer.minutes(5)


	defp main_master_handler(state) do
		refresh_self(state)
			|> refresh_slaves
				|> refresh_other_hosts
					|> encode_and_put_to_cache
						|> send_signal_to_web_viewers
	end


	defp refresh_slaves(state = %MasterState{}) do
		HashUtils.modify_all(state, :slaves_info, 
			#fn(appinfo = %Genom.AppInfo{stamp: stamp}) ->
			fn(appinfo) -> IO.inspect appinfo
				stamp = appinfo.stamp
				case (Exutils.makestamp - stamp) > @slave_death_timeout do
					true -> HashUtils.set(appinfo, :status, :dead)
					false -> appinfo
				end
			end )
	end
	defp refresh_other_hosts(state = %Genom.Unit.MasterState{}) do
		HashUtils.modify_all(state, [:other_hosts], 
			fn(hostinfo = %Genom.HostInfo{host: host, port: port, stamp: stamp}) ->
				case ((Exutils.makestamp - stamp) > @host_death_timeout) and (try_send_my_hostinfo(host, port, prepare_host_info(state)) != :ok ) do
					true -> HashUtils.set(hostinfo, :status, :dead)
					false -> hostinfo
				end
			end )
	end
	defp encode_and_put_to_cache state do
		IO.puts "encode_and_put_to_cache"
		%Genom.Bullet.WebProtocol{ subject: "refresh", content: Exutils.prepare_to_jsonify(state, %{tuple_values_to_lists: true}) }
			|> Jazz.encode!
				|> Genom.Tinca.put(:web_view_cache)
		state
	end
	defp send_signal_to_web_viewers state do
		spawn_link fn() ->
					:pg2.get_members("web_viewers")
						|> Enum.each( fn(viewer) -> send(viewer, "refresh") end )
					end
		state
	end
	defp merge_incoming_hostinfo(hosts_list, hostinfo = %Genom.HostInfo{host: host, port: port}) do
		case Enum.filter(hosts_list,
				fn( %Genom.HostInfo{host: inner_host, port: inner_port} ) -> 
					(inner_host == host) and (inner_port == port) end) do
			[] -> [hostinfo|hosts_list]
			[existing = %Genom.HostInfo{comment: comment}] -> 
				case comment == "" do
					false -> (hosts_list--[existing])++[HashUtils.set(hostinfo, :comment, comment)]
					true ->  (hosts_list--[existing])++[hostinfo]
				end
		end
	end

	###############################################
	###	external hosts communication priv funcs ###
	###############################################

	defp prepare_host_info( %MasterState{my_info: my_info = %Genom.AppInfo{id: id, port: port}, slaves_info: slaves_info} ) do
		%Genom.HostInfo{apps: HashUtils.add(slaves_info, id, my_info), port: port, stamp: Exutils.makestamp, status: :alive, comment: Genom.Tinca.get(:my_comment)}
			|> :erlang.term_to_binary
				|> :base64.encode
	end
	defp try_send_my_hostinfo(host, port, my_hostinfo_bin) do
		case Retry.run( %{sleep: 500, tries: 5}, fn() -> try_send_my_hostinfo_process(host, port, my_hostinfo_bin) end ) do
			{:ok, _} -> :ok
			err -> 	Logger.warn "Genom.Unit : exchange with host #{host}:#{port} failed, code is #{inspect err}"
		end
	end
	defp try_send_my_hostinfo_process(host, port, my_hostinfo_bin) do
		%HTTPoison.Response{status_code: 200, body: "ok"} = 
			HTTPoison.post("http://#{host}:#{port}/external",
			my_hostinfo_bin,
			[{"Content-Type","text/plain"}])
	end

end