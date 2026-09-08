defmodule StrangepathsWeb.UserSettingsControllerTest do
  use StrangepathsWeb.ConnCase, async: true

  alias Strangepaths.Accounts
  import Strangepaths.AccountsFixtures

  setup :register_and_log_in_user

  describe "GET /users/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, Routes.user_settings_path(conn, :edit))
      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :edit))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end
  end

  describe "PUT /users/settings (change password form)" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_password",
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == Routes.user_settings_path(conn, :edit)
      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_password",
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
      assert response =~ "is not valid"

      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "PUT /users/settings (change email form)" do
    @tag :capture_log
    test "updates the user email", %{conn: conn, user: user} do
      conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_email",
          "current_password" => valid_user_password(),
          "user" => %{"email" => unique_user_email()}
        })

      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_email",
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "is not valid"
    end
  end

  describe "GET /users/settings/confirm_email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "Email changed successfully"
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end
  end

  describe "PUT /users/settings (update notification prefs)" do
    test "renders settings page with notification preferences form", %{conn: conn} do
      conn = get(conn, Routes.user_settings_path(conn, :edit))
      response = html_response(conn, 200)
      assert response =~ "Activity notifications"
      assert response =~ "name=\"user[notif_scene_sound]\""
      assert response =~ "name=\"user[notif_scene_web]\""
      assert response =~ "name=\"user[notif_library_sound]\""
      assert response =~ "name=\"user[notif_library_web]\""
      assert response =~ "name=\"user[notif_bbs_sound]\""
      assert response =~ "name=\"user[notif_bbs_web]\""
      assert response =~ "name=\"user[notif_rumor_sound]\""
      assert response =~ "name=\"user[notif_rumor_web]\""
      assert response =~ "id=\"notif-perm-note\""
    end

    test "updates notification preferences", %{conn: conn, user: user} do
      conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_notification_prefs",
          "user" => %{
            "notif_scene_sound" => "true",
            "notif_library_web" => "true"
          }
        })

      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "Activity notification preferences updated"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.notif_scene_sound == true
      assert updated_user.notif_library_web == true
      assert updated_user.notif_scene_web == false
      assert updated_user.notif_library_sound == false
      assert updated_user.notif_bbs_sound == false
      assert updated_user.notif_bbs_web == false
      assert updated_user.notif_rumor_sound == false
      assert updated_user.notif_rumor_web == false
    end

    test "ignores unknown fields in notification prefs update", %{conn: conn, user: user} do
      conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_notification_prefs",
          "user" => %{
            "notif_scene_sound" => "true",
            "role" => "dragon"
          }
        })

      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.notif_scene_sound == true
      assert updated_user.role == :user
    end
  end
end
