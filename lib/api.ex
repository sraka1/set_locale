defmodule SetLocale.Api do
  @moduledoc """
  Module for setting locale from Accept-Language header.

  This implementation is appropriate for API use-cases only.
  The only thing this plug does is determining the locale from
  the `Accept-Language` header and setting the locale to gettext.

  The options for the plugs are
   - gettext: mandatory
   - default_locale: mandatory, used as last step in fallback chain
   - additional_locales: optional, if given it allows to whitelist locales that are not defined via Gettext. Possible scenario: You want to use Gettext and some SaaS localization service (e.g. http://bablic.com/) in parallel. Whitelisting these additional languages allows you to have proper routing for the locales and trigger the wanted JS behaviour depending on the assigned locale in your templates.
  """

  import Plug.Conn

  defmodule Config do
    @moduledoc "Struct for SetLocale config."
    @enforce_keys [:gettext, :default_locale]
    defstruct [:gettext, :default_locale, additional_locales: []]
  end

  def init(opts) when is_tuple(hd(opts)), do: struct!(Config, opts)

  def call(%Plug.Conn{} = conn, config) do
    requested_locale = determine_locale(conn, config)

    if supported_locale?(requested_locale, config) do
      if Enum.member?(config.additional_locales, requested_locale) do
        Gettext.put_locale(config.gettext, config.default_locale)
      else
        Gettext.put_locale(config.gettext, requested_locale)
      end
    else
      Gettext.put_locale(config.gettext, config.default_locale)
    end

    assign(conn, :locale, requested_locale)
  end

  defp determine_locale(conn, config) do
    determined_locale = get_locale_from_header(conn, config)

    if supported_locale?(determined_locale, config),
      do: determined_locale,
      else: config.default_locale
  end

  defp get_locale_from_header(conn, gettext) do
    conn
    |> SetLocale.Headers.extract_accept_language()
    |> Enum.find(nil, fn accepted_locale -> supported_locale?(accepted_locale, gettext) end)
  end

  defp supported_locale?(locale, config), do: Enum.member?(supported_locales(config), locale)

  defp supported_locales(config),
    do: Gettext.known_locales(config.gettext) ++ config.additional_locales
end
