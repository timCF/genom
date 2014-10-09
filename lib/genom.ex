defmodule Genom do
  use Application
  use Tinca, [:genom_cache]

  @default_port 8999

  defmodule Host do
    @derive [HashUtils]
    defstruct host: nil, port: nil
  end



  defmacro add_info(value, key) do
    quote do
      Genom.ModulesCacheWriter.add_info(__MODULE__, unquote(key), { Exutils.makestamp, unquote(value) } )
    end
  end



  # role = :master | :slave
  # status = :alive | :dead
  defmodule AppInfo do
    @derive [HashUtils]
    defstruct id: nil, role: :slave, status: :alive, modules_info: nil, port: nil, stamp: 0
  end
  defmodule HostInfo do
    @derive [HashUtils]
    defstruct apps: %{}, host: nil, port: nil, stamp: 0, status: :dead
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    Tinca.declare_namespaces

    :application.get_all_env(:genom)
      |> store_my_info_to_hash

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Genom.Worker, [arg1, arg2, arg3])
    ]
    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Genom.Supervisor]
    Supervisor.start_link(children, opts)
  end


  # get here other hosts settings, own port, generate own id, and store all this info to hash
  defp store_my_info_to_hash env do
    get_conf_file_path(env) |> store_hosts
    store_port(env)
    Exutils.makecharid |> Tinca.put(:my_id)
  end
  defp store_hosts conf_filename do
    case File.read(conf_filename) do
      {:ok, _} ->
        :yaml.load_file(conf_filename)
            |> make_hosts_map
                |> Enum.map(&parse_host/1)
                    |> Tinca.put(:hosts)
      _ ->  Logger.warn "Genom : hosts configuration file not found! Genom will not try to connect to other hosts, but will handle incoming connections."
            Tinca.put([], :hosts)
    end
  end
  defp store_port env do
    case env[:port] do
      nil -> Tinca.put( @default_port, :my_port )
      some when (is_integer(some) and (some > 0)) -> Tinca.put( some, :my_port )
    end
  end


  defp get_conf_file_path(env) do
    (env[:app] |> Exutils.priv_dir)<>"/genom.yml"
  end
  defp make_hosts_map({:ok, [%{"hosts" => hosts_raw}]}) do
    Enum.map(hosts_raw, 
      fn( host = %{host: hostname} ) ->
        case HashUtils.get(host, :port) do
          nil -> %Host{host: hostname, port: @default_port}
          some -> %Host{host: hostname, port: some}
        end
      end )
  end
  defp parse_host(%Host{host: host, port: port}) when (is_binary(host) and is_integer(port) and (port > 0)) do
    {:ok, {q,w,e,r}} = host |> String.to_char_list |> :inet.parse_ipv4_address
    %Host{port: port, host:
      Enum.map([q,w,e,r], &(to_string(&1)))
        |> Enum.join(".")}
  end


end
