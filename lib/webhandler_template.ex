defmodule Genom.WebhandlerTemplate do
	defmacro __using__(_options) do
		quote location: :keep do

			#################
			### callbacks ###
			#################

			def init( req, opts) do
				{
					:http,
					req,
					case :cowboy_req.has_body(req) do
						true -> prev_parse(req, opts)
						false -> {:error, "Genom : error, query has not any body.", opts}
					end
				}
			end
			def terminate(_,_,_), do: :ok
			def handle(req, {:error, some_err, opts}) do
				reply some_err, req, opts
			end

			#################################
			### for usage in using module ###
			#################################

			defp reply(ans, req, opts) when is_binary(ans) do
				IO.puts "Genom.Server : send answer #{ans}"
				{
					:ok,
					:cowboy_req.reply(200, [{"content-type", "text/plain"}], ans, req),
					opts
				}
			end

			############
			### priv ###
			############

			defp prev_parse(req, opts) do
				body = :cowboy_req.body(req) |> elem(1)
				case ExTask.run( fn() -> body |> :base64.decode |> :erlang.binary_to_term end )
						|> ExTask.await(:infinity) do
					{:result, erlang_term} -> {:ok, erlang_term, opts}
					errr -> {:error, "Genom : error, can't decode data to erlang term. Content : #{inspect errr}", opts}
				end
			end

		end
	end
end