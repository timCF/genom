defmodule Genom do
  use Application
  use Tinca, [:genom_cache]
  use Hashex, [Genom.Host, Genom.AppInfo, Genom.HostInfo]
  require Logger

  @default_port 8999

  defmodule Host do
    defstruct host: nil, port: nil, comment: ""
  end

  # role = :master | :slave
  # status = :alive | :dead
  defmodule AppInfo do
    defstruct id: nil, name: nil, role: :slave, status: :alive, modules_info: nil, port: nil, stamp: 0, comment: ""
  end
  defmodule HostInfo do
    defstruct apps: %{}, host: nil, port: nil, stamp: 0, status: :dead, comment: ""
  end



  defmacro add_info(value, key) do
    quote do
      val = unquote(value) # !! to not execute expr "value" twice
      case ExTask.run(fn() -> Genom.ModulesCacheWriter.add_info(__MODULE__, unquote(key), %{stamp: Exutils.make_verbose_datetime, value: val} ) end)
            |> ExTask.await(:timer.seconds(10)) do
        {:result, res} -> res
        error ->  Logger.warn "GENOM : Value was not stored. Val was #{inspect val}. Error : #{inspect error}."
                  val
      end
    end
  end


  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    Tinca.declare_namespaces

    :application.get_all_env(:genom)
      |> store_my_info_to_hash

    children = [
      worker(Genom.ModulesCacheWriter, []),
      worker(Genom.Unit, [])
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
    store_appname(env)
    store_comment(env)
    store_perm_slave_option(env)
    Exutils.makecharid |> Tinca.put(:my_id)
  end
  defp store_hosts conf_filename do
    case File.read(conf_filename) do
      {:ok, _} ->
        :yaml.load_file(conf_filename, [:implicit_atoms])
            |> make_hosts_map
                |> Enum.map(&parse_host/1)
                    |> Tinca.put(:hosts)
      _ ->  Logger.warn "Genom : hosts configuration file not found! Genom will not try to connect to other hosts now, but will handle incoming connections."
            Tinca.put([], :hosts)
    end
  end
  defp store_port env do
    case env[:port] do
      nil -> Tinca.put( @default_port, :my_port )
      some when (is_integer(some) and (some > 0)) -> Tinca.put( some, :my_port )
    end
  end
  defp store_appname(env) do
    case env[:app] do
      nil -> Tinca.put( :undefined, :my_app )
      some when is_atom(some) -> Tinca.put(some, :my_app)
    end
  end
  defp store_comment(env) do
    case env[:comment] do
      nil -> Tinca.put( "", :my_comment )
      some when is_binary(some) -> Tinca.put(some, :my_comment)
    end
  end
  defp store_perm_slave_option(env) do
    case env[:permanent_slave] do
      nil -> Tinca.put(false, :perm_slave_option)
      false -> Tinca.put(false, :perm_slave_option)
      true -> Tinca.put(true, :perm_slave_option)
    end
  end

  defp get_conf_file_path(env) do
    (env[:app] |> Exutils.priv_dir)<>"/genom.yml"
  end
  defp make_hosts_map({:ok, [%{hosts: hosts_raw_lst}]}) do
    check_hosts(hosts_raw_lst)
    |> Enum.map( 
      fn( host = %{host: hostname} ) ->
        case HashUtils.get(host, :port) do
          nil -> %Host{host: hostname, port: @default_port, comment: HashUtils.get(host, :comment) |> to_string}
          some -> %Host{host: hostname, port: some, comment: HashUtils.get(host, :comment) |> to_string}
        end
      end )
  end
  defp parse_host(%Host{host: host, port: port, comment: comment}) when (is_binary(host) and is_integer(port) and (port > 0)) do
    {:ok, {q,w,e,r}} = host |> String.to_char_list |> :inet.parse_ipv4_address
    %Host{port: port, comment: comment, host:
      Enum.map([q,w,e,r], &(to_string(&1)))
        |> Enum.join(".")}
  end

  defp check_hosts(hosts_raw_lst) do
    Enum.map(hosts_raw_lst, 
      fn(host) ->
        case Enum.filter(hosts_raw_lst,
          fn(host_inner) -> 
            HashUtils.get(host_inner, :port) == HashUtils.get(host, :port)
            and
            HashUtils.get(host_inner, :host) == HashUtils.get(host, :host)
          end) do

          [^host] -> host
          some_hosts -> raise "Genom : wrong config file! Host #{inspect host} is similar to #{inspect some_hosts}"

        end
      end )
  end


end
