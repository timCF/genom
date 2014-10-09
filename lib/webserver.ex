defmodule Genom.WebServer do
	require Logger

	def start do

		File.rm( Exutils.priv_dir(:genom)<>"/js/scripts.js" )
		:os.cmd("cd #{Exutils.priv_dir(:genom)} && iced -c ./scripts.iced && mv ./scripts.js ./js/scripts.js" |> String.to_char_list)
		File.read!( Exutils.priv_dir(:genom)<>"/js/scripts.js" )

		:pg2.create "web_viewers"

  		dispatch = :cowboy_router.compile([
                      {:_, [
                               {"/internal", Genom.Internal, []},
                               {"/external", Genom.External, []},
                               {"/bullet", :bullet_handler, [{:handler, Genom.InterfaceBullet}]},
                               {"/", :cowboy_static, {:priv_file, :genom, "index.html"}},
                               {"/[...]", :cowboy_static, {:priv_dir, :genom, "", [{:mimetypes, :cow_mimetypes, :all}]}}
                        ]} ])
    	res = {:ok, _} = :cowboy.start_http(:http_test_listener, 5000, [port: @my_port], [env: [ dispatch: dispatch ] ])
    	Logger.info "HTTP Server started at port #{@my_port}"
    	res
  	end
	def init(_type, req, []) do
		{:ok, req, :undefined}
	end
	def terminate(_Reason, _Req, _State) do
		:ok
	end
end