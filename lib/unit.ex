defmodule Genom.Unit do
	
	use ExActor.GenServer, export: :GenomUnit
	@timeout :timer.minutes(1)

	defmodule MasterState do
		@derive [HashUtils]
		defstruct my_info: %AppInfo{}, slaves_info: %{}, other_hosts: []
	end
	defmodule SlaveState do
		@derive [HashUtils]
		defstruct my_info: %AppInfo{}
	end

	definit do
		{:ok, :initialized, 0}
	end
	definfo :timeout, :initialized do
		case create_state |> report_to_master do
			:failed -> became_master
			:ok -> beacme_slave
		end
	end



	defp create_state do
		%SlaveState{ my_info: %AppInfo{ 
			id: Genom.Tinca.get(:my_id),
			role: :slave,
			status: :alive,
			modules_info: Genom.Tinca.get(:modules_info),
			port: Genom.Tinca.get(:my_port)
			stamp: Exutils.makestamp }}
	end
	defp report_to_master( state = %SlaveState{my_info: my_info = %AppInfo{ port: my_port }} ) do
		case try_report_to_master(my_info, my_port) do
			{:ok, _} -> :ok
			err -> 	Logger.warn "Genom.Unit : report to master failed, code is #{inspect err}"
					:failed
		end
	end
	defp try_report_to_master(my_info, my_port) do
		Retry.run( %{sleep: 500, tries: 3}, 
			fn() -> 
				%HTTPoison.Response{status_code: 200, body: "ok"} = HTTPoison.post("http://localhost:#{my_port}/inner",
				[app_info: my_info |> :erlang.term_to_binary |> :base64.encode] |> Exutils.HTTP.make_args,
				[{"Content-Type","application/x-www-form-urlencoded"}])
			end )
	end



	defp became_master do
		
	end

end