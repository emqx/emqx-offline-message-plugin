defmodule EMQXOfflinePlugin.MixProject do
  use Mix.Project

  def project do
    [
      app: :emqx_offline_message_plugin,
      version: version(),
      compilers: Mix.compilers() ++ [:copy_srcs],
      extra_dirs: extra_dirs(),
      emqx_plugin: emqx_plugin(),
      build_path: emqx_path("_build"),
      deps_path: emqx_path("deps"),
      lockfile: emqx_path("mix.lock"),
      erlc_paths: erlc_paths(),
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def test_env?() do
    to_string(Mix.env()) =~ ~r/-test$/
  end

  def erlc_paths() do
    if test_env?() do
      ["src", "test"]
    else
      ["src"]
    end
  end

  def version do
    "2.0.0"
  end

  def application do
    [
      extra_applications: [],
      mod: {:emqx_offline_message_plugin_app, []}
    ]
  end

  def deps() do
    [
      {:emqx_mix, path: emqx_path(), env: emqx_mix_env()},
      # {:emqx_plugin_helper, github: "emqx/emqx-plugin-helper", tag: "v5.9.0"},
    ]
  end

  defp emqx_path(to_join \\ nil) do
    path = "/emqx"
    if to_join do
      Path.join(path, to_join)
    else
      path
    end
  end

  defp emqx_mix_env() do
    if test_env?() do
      :"emqx-enterprise-test"
    else
      :"emqx-enterprise"
    end
  end

  defp emqx_plugin do
    [
      rel_vsn: version(),
      metadata: [
        authors: ["EMQX"],
        builder: [
          name: "EMQX",
          contact: "developer@emqx.io",
          website: "https://www.emqx.com"
        ],
        repo: "https://github.com/emqx/emqx",
        functionality: ["Offline message persistence"],
        compatibility: [
          emqx: "~> 6.0"
        ],
        description: "Offline message persistence plugin for EMQX."
      ]
    ]
  end

  defp extra_dirs() do
    dirs = []

    if test_env?() do
      ["test" | dirs]
    else
      dirs
    end
  end
end
