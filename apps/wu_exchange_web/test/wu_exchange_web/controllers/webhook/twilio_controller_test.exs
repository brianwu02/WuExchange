defmodule WuExchangeWeb.Webhook.TwilioControllerTest do
  use WuExchangeWeb.ConnCase

  alias WuExchangeBackend.WuExchangeBackend
  alias WuExchangeBackend.WuExchangeBackend.Twilio

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:twilio) do
    {:ok, twilio} = WuExchangeBackend.create_twilio(@create_attrs)
    twilio
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all twilios", %{conn: conn} do
      conn = get conn, webhook_twilio_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create twilio" do
    test "renders twilio when data is valid", %{conn: conn} do
      conn = post conn, webhook_twilio_path(conn, :create), twilio: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, webhook_twilio_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, webhook_twilio_path(conn, :create), twilio: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update twilio" do
    setup [:create_twilio]

    test "renders twilio when data is valid", %{conn: conn, twilio: %Twilio{id: id} = twilio} do
      conn = put conn, webhook_twilio_path(conn, :update, twilio), twilio: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, webhook_twilio_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn, twilio: twilio} do
      conn = put conn, webhook_twilio_path(conn, :update, twilio), twilio: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete twilio" do
    setup [:create_twilio]

    test "deletes chosen twilio", %{conn: conn, twilio: twilio} do
      conn = delete conn, webhook_twilio_path(conn, :delete, twilio)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, webhook_twilio_path(conn, :show, twilio)
      end
    end
  end

  defp create_twilio(_) do
    twilio = fixture(:twilio)
    {:ok, twilio: twilio}
  end
end
