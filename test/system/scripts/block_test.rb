require "application_system_test_case"

class BlockTest < ApplicationSystemTestCase
  test "banned via disallowed url" do
    user = User.find(4)
    login_as(user, scope: :user)
    visit new_script_version_url
    click_link "I've written a script and want to share it with others."
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // @include *
      // ==/UserScript==
      location.href = "https://example.com/unique-test-value"
    EOF
    fill_in 'Code', with: code
    assert_changes -> { user.reload.banned }, from: false, to: true do
      allow_js_error /the server responded with a status of 403 \(Forbidden\)/ do
        click_button 'Post script'
        assert_content 'This script has been deleted'
      end
    end
  end

  test "blocked with originating script" do
    login_as(User.find(4))
    visit new_script_version_url
    click_link "I've written a script and want to share it with others."
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // @include *
      // ==/UserScript==
      some.unique[value]
    EOF
    fill_in 'Code', with: code
    click_button 'Post script'
    assert_content 'This appears to be an unauthorized copy'
  end

  test "not blocked when same author" do
    origin = scripts(:copy_origin)
    login_as(origin.users.first, scope: :user)
    visit new_script_version_url
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // @include *
      // ==/UserScript==
      some.unique[value]
    EOF
    fill_in 'Code', with: code
    assert_difference -> { ScriptVersion.count } => 1 do
      click_button 'Post script'
    end
  end

  test "updating originating script" do
    origin = scripts(:copy_origin)
    login_as(origin.users.first, scope: :user)
    visit new_script_script_version_url(script_id: origin.id)
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // @include *
      // ==/UserScript==
      some.unique[value]
    EOF
    fill_in 'Code', with: code
    assert_difference -> { ScriptVersion.count } => 1 do
      click_button 'Post new version'
    end
  end

  test "banned via disallowed text" do
    user = User.find(4)
    login_as(user, scope: :user)
    visit new_script_version_url
    click_link "I've written a script and want to share it with others."
    code = <<~EOF
      // ==UserScript==
      // @name A Test!
      // @description Unit test.
      // @version 1.1
      // @namespace http://greasyfork.local/users/1
      // @include *
      // ==/UserScript==
      location.href = "badguytext"
    EOF
    fill_in 'Code', with: code
    assert_difference -> { Script.count } => 1 do
      click_button 'Post script'
      assert_content 'This script is unavailable to other users until it is reviewed by a moderator.'
    end
    assert_equal 'required', Script.last.review_state
  end
end