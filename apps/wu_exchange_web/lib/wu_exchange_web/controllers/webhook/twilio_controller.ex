defmodule WuExchangeWeb.Webhook.TwilioController do
  @moduledoc """
  Twilio Response documentation https://www.twilio.com/docs/api/twiml/sms/twilio_request
  """
  use WuExchangeWeb, :controller

  alias WuExchangeBackend.SMSParser

  action_fallback WuExchangeWeb.FallbackController

  @doc"""
  """
  def create(conn, %{"Body" => body, "From" => from} = params) do
    {:ok, acknowledge_str} = Timex.now("America/New_York")
                             |> Timex.format("{RFC1123}")

    {:ok, command} = SMSParser.parse_sms(body)

    xml_string = """
    <?xml version="1.0" encoding="utf-8"?>
    <Response>
      <Message>Received: #{body}</Message>
      <Message>Acknowledged at #{acknowledge_str}</Message>
    </Response>
    """

    conn
    |> put_resp_content_type("text/xml")
    |> put_status(:created)
    |> send_resp(200, xml_string)
  end

end
