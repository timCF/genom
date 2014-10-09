defmodule Genom.Unit do
	
	use ExActor.GenServer, export: :GenomUnit
	@timeout :timer.minutes(1)

	defmodule MasterState do
		@derive [HashUtils]
		defstruct my_info: %Genom.AppInfo{}, slaves_info: %{}, other_hosts: []
	end
	defmodule SlaveState do
		@derive [HashUtils]
		defstruct my_info: %Genom.AppInfo{}
	end

	definit do
		state = create_state |> refresh_self
		{
			:ok, 
			case report_to_master(state) do
				:failed -> become_master(state)
				:ok -> state
			end,
			@timeout
		}
	end



	#
	#	TODO : defcall from cowboy - incoming hostinfo
	#	dynamically can add new hosts))
	#
	#


	definfo :timeout, state: state = %SlaveState{} do
		new_state = state |> refresh_self
		{
			:noreply,
			case new_state |> report_to_master do
				:failed -> become_master(new_state)
				:ok -> new_state
			end,
			@timeout
		}
	end
	definfo :timeout, state: state = %MasterState{} do
		{
			:noreply,
			refresh_self(state)
				|> refresh_slaves
					|> refresh_other_hosts
						|> encode_and_put_to_cache
							|> send_signal_to_web_viewers,
			@timeout
		}
	end

	#######################
	### init priv funcs ###
	#######################

	defp create_state do
		%SlaveState{ my_info: %Genom.AppInfo{ 
			id: Genom.Tinca.get(:my_id),
			role: :slave,
			status: :alive,
			modules_info: Genom.Tinca.get(:modules_info),
			port: Genom.Tinca.get(:my_port)
			stamp: Exutils.makestamp }}
	end
	defp become_master %SlaveState{ my_info: my_info = %Genom.AppInfo{port: port} } do
		#
		#	TODO : start web-server
		#
		%MasterState{ 
			my_info: HashUtils.set(my_info, :role, :master),
			slaves_info: %{},
			other_hosts: Genom.Tinca.get(:hosts) 
							|> Enum.map(&create_host_struct/1) }
	end
	defp create_host_struct %Genom.Host{host: host, port: port} do
		%Genom.HostInfo{apps: %{}, host: host, port: port, stamp: 0, status: :dead }
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
	defp refresh_timestamp do
		HashUtils.set(state, [:my_info, :stamp],
			Exutils.makestamp)
	end

	########################
	### slave priv funcs ###
	########################

	defp report_to_master( state = %SlaveState{my_info: my_info = %Genom.AppInfo{ port: my_port }} ) do
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

	defp refresh_slaves(state = %MasterState{}) do
		HashUtils.modify_all(state, :slaves_info, 
			fn(appinfo = %Genom.AppInfo{stamp: stamp}) ->
				case (Exutils.makestamp - stamp) > @slave_death_timeout do
					true -> HashUtils.set(appinfo, :status, :dead)
					false -> appinfo
				end
			end )
	end
	defp refresh_other_hosts(state = %MasterState{}) do
		HashUtils.modify_all(state, :other_hosts, 
			fn(hostinfo = %Genom.HostInfo{host: host, port: port, stamp: stamp}) ->
				case ((Exutils.makestamp - stamp) > @host_death_timeout) and (try_send_my_hostinfo(host, port, prepare_host_info(state)) != :ok ) do
					true -> HashUtils.set(hostinfo, :status, :dead)
					false -> hostinfo
				end
			end )
	end
	defp encode_and_put_to_cache state do
		Exutils.prepare_to_jsonify(state, %{tuple_values_to_lists: true})
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

	###############################################
	###	external hosts communication priv funcs ###
	###############################################

	defp prepare_host_info( %MasterState{my_info: my_info = %Genom.AppInfo{id: id, port: port}, slaves_info: slaves_info} ) do
		%Genom.HostInfo{apps: HashUtils.add(slaves_info, id, my_info), port: port, stamp: Exutils.makestamp, status: :alive}
			|> :erlang.term_to_binary
				|> :base64.encode
	end
	defp try_send_my_hostinfo(host, port, my_hostinfo_bin) do
		case Retry.run( %{sleep: 500, tries: 5}, try_send_my_hostinfo_process(host, port, my_hostinfo_bin)) do
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