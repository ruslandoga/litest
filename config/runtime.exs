import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

config :logger, :console, format: "$time [$level] $message\n"

if System.get_env("WEB_SERVER") do
  config :e, E.Endpoint, server: true
end

if config_env() == :prod do
  log_level =
    if level = System.get_env("LOG_LEVEL") || "info" do
      String.to_existing_atom(level)
    end

  config :logger, level: log_level

  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/e/e.db
      """

  config :e, E.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    # https://litestream.io/tips/#disable-autocheckpoints-for-high-write-load-servers
    wal_auto_check_point: 0,
    # https://litestream.io/tips/#busy-timeout
    busy_timeout: 5000,
    cache_size: -2000

  port = String.to_integer(System.get_env("PORT") || "4000")

  config :e, E.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ]
end

if config_env() == :dev do
  config :e, E.Repo,
    database: Path.expand("../e_dev.db", Path.dirname(__ENV__.file)),
    show_sensitive_data_on_connection_error: true,
    pool_size: 10

  config :e, E.Endpoint, http: [ip: {127, 0, 0, 1}, port: 4000]
end

if config_env() == :bench do
  config :e, E.Repo,
    database: Path.expand("../e_bench.db", Path.dirname(__ENV__.file)),
    cache_size: -2000,
    pool_size: 10

  config :e, E.Endpoint, http: [ip: {127, 0, 0, 1}, port: 4000]
end

if config_env() == :test do
  config :logger, level: :warn

  # Configure your database
  #
  # The MIX_TEST_PARTITION environment variable can be used
  # to provide built-in test partitioning in CI environment.
  # Run `mix help test` for more information.
  config :e, E.Repo,
    database:
      Path.expand(
        "../e_test#{System.get_env("MIX_TEST_PARTITION")}.db",
        Path.dirname(__ENV__.file)
      ),
    pool: Ecto.Adapters.SQL.Sandbox

  config :e, E.Endpoint, http: [ip: {127, 0, 0, 1}, port: 4002]
end
