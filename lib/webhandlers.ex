defmodule Genom.Internal do
	use Genom.WebhandlerTemplate
	def handle(req, {:ok, slave_info = %Genom.AppInfo{}, opts}) do
		Genom.Unit.add_slaveinfo(slave_info)
		reply("ok",req, opts)
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
		reply("ok",req, opts)
	end
	def handle(req, {:ok, some_term, opts}) do
		"Genom.External : error, expect term %Genom.HostInfo{}, but got #{inspect some_term}"
			|> reply(req, opts)
	end
end


defmodule Genom.Bullet do

	require Logger
	@pong (%{subject: "pong", content: ""} |> Jazz.encode!)

	defmodule WebProtocol do
		@derive [HashUtils]
		defstruct subject: "error", content: nil
	end

	########################
	### public callbacks ###
	########################

	def init(_Transport, req, _Opts, _Active) do
		:pg2.join "web_viewers", self
		Logger.info "Bullet handler: init"
		{:ok, req, :undefined_state}
	end

	def stream(data, req, state) do
		ans = case mess = (Jazz.decode(data, keys: :atoms)) do
		    {:ok, map} -> case map do
		                    %{subject: subject, content: content} -> handle_message_from_client(%WebProtocol{subject: subject, content: content})
		                    _ -> Jazz.encode!(%WebProtocol{content: "Error on protocol from client. Content: #{inspect mess}"})
		                  end
		    _ ->  Jazz.encode!(%WebProtocol{content: "parsing JSON error on server\nincoming messge:\n#{inspect data}"})
		  end
		{:reply, ans, req, state}
	end

	def info("refresh", req, state) do
		{
			:reply,
			Genom.Tinca.get(:web_view_cache),
			req,
			state
		}
	end
	def info(info, req, state) do
		Logger.warn "Bullet handler: unexpected info #{inspect info}"
		{:ok, req, state}
	end

	def terminate(req, state) do
		:pg2.leave "web_viewers", self
		Logger.warn "Bullet handler: terminate #{inspect req} and #{inspect state}"
	end

	#############################################
	### private handlers for mess from client ###
	#############################################

	defp handle_message_from_client(%WebProtocol{subject: "get_state"}) do
		Genom.Tinca.get(:web_view_cache)
	end
	defp handle_message_from_client(%WebProtocol{subject: "ping"}) do
		@pong
	end

end