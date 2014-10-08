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

	defp report_to_master slave = %SlaveState{port: my_port} do
		
	end


end