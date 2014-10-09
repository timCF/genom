defmodule Genom.WebhandlerTemplate do
	defmacro __using__(_options) do
		quote location: :keep do
			def init( req, opts) do
				{:ok, erlang_term, _req} = 
				case :cowboy_req.has_body(req) do
					true ->
							{:ok, body, req} = :cowboy_req.body(req)
							case :jsx.is_json body do
								true -> {:ok, :jsx.decode(body) |> HashUtils.to_map , req}
								false -> {:ok, kv |> HashUtils.to_map, req}
							end
					false ->
							{:ok, {:error, "Genom : error, query has not any body."}, req}
				end
				{
					:http,
					req,
					case :cowboy_req.has_body(req) do
						true -> prev_parse_query(req)
						false -> {:error, "Genom : error, query has not any body."}
					end
				}
			end
			def reply(ans, req, opts) when is_binary(ans) do
				IO.puts "Got send answer #{ans}"
				{
					:ok,
					:cowboy_req.reply(200, [{"content-type", "text/plain"}], ans, req),
					opts
				}
			end
			def terminate(_,_,_), do: :ok

			defp prev_parse_query(req) do
				body = :cowboy_req.body(req) |> elem(1)
				case ExTask.run( fn() -> body |> :base64.decode |> :erlang.binary_to_term end )
						|> ExTask.await(:infinity) do
					{:result, erlang_term} -> {:ok, erlang_term}
					errr -> {:error, "Genom : error, can't decode data to erlang term. Content : #{inspect errr}"}
				end
			end

		end
	end
end