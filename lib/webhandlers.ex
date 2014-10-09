defmodule Genom.Internal do
	use Genom.WebhandlerTemplate

	def handle(req, {:ok, slave_info = %Genom.AppInfo{}, opts}) do
		Genom.Unit.add_slaveinfo(slave_info)
			|> reply(req, opts)
	end
	def handle(req, {:ok, some_term, opts}) do
		"Genom.Internal : error, expect term %Genom.AppInfo{}, but got #{inspect some_term}"
			|> reply(req, opts)
	end

end

defmodule Genom.External do
	use Genom.WebhandlerTemplate
	
	def handle(req, {:ok, host_info = %Genom.HostInfo{}, opts}) do
		Genom.Unit.add_hostinfo(host_info)
			|> reply(req, opts)
	end
	def handle(req, {:ok, some_term, opts}) do
		"Genom.External : error, expect term %Genom.HostInfo{}, but got #{inspect some_term}"
			|> reply(req, opts)
	end

end