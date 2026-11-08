import Config

# Use shoehorn to start the main application. See the shoehorn
# library documentation for more control in ordering how OTP
# applications are started and handling failures.

config :shoehorn, init: [:nerves_runtime, :nerves_pack]

# The guard would otherwise validate the slot after boot; the A/B test needs
# the slot left unvalidated.
config :nerves_runtime, startup_guard_enabled: false

# Advance the system clock on devices without a real-time clock.
config :nerves, :erlinit, update_clock: true

# Default to not starting so that the console logger isn't started. See
# runtime.exs for logger configuration.
config :logger, :default_handler, false

config :nerves_ssh,
  authorized_keys:
    Enum.map(
      ["id_ed25519.pub", "id_rsa.pub"],
      &(System.user_home!() |> Path.join(".ssh/#{&1}") |> File.read!())
    )

# wlan0 has no network so the interface exists for later hardware checks.
config :vintage_net,
  regulatory_domain: "00",
  config: [
    {"eth0",
     %{
       type: VintageNetEthernet,
       ipv4: %{method: :dhcp}
     }},
    {"wlan0",
     %{type: VintageNetWiFi, vintage_net_wifi: %{networks: []}, ipv4: %{method: :disabled}}}
  ]

config :mdns_lite,
  hosts: ["rock4d"],
  ttl: 120,

  # Advertise the following services over mDNS.
  services: [
    %{
      protocol: "ssh",
      transport: "tcp",
      port: 22
    }
  ]
