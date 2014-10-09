defmodule Genom.Mixfile do
  use Mix.Project

  def project do
    [app: :genom,
     version: "0.0.1",
     elixir: "~> 1.0.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications:  [
                      :logger,
                      :yamler,
                      :httpoison,
                      :retry,
                      :exactor,
                      :cowboy,
                      :extask,
                      :jazz,
                      :bullet,

                      :tinca,
                      :hashex
                    ],
     mod: {Genom, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:yamler, github: "goertzenator/yamler", branch: "mapping_as_map"},
      {:httpoison, github: "edgurgel/httpoison"},
      {:retry, github: "d0rc/retry"},
      {:exactor, github: "sasa1977/exactor"},
      {:cowboy, github: "ninenines/cowboy", override: true, tag: "b57f94661f5fd186f55eb"},
      {:bullet, github: "extend/bullet"},
      {:extask, github: "timCF/extask"},
      {:jazz, github: "meh/jazz"},

      {:tinca, github: "timCF/tinca"},
      {:exutils, github: "timCF/exutils"},
      {:hashex, github: "timCF/hashex"}
    ]
  end
end
