Visitors should be in control of creating an account and of proving their
essential humanity/accountability or whatever it is people think the
id-validation does.  We should be fairly skeptical about this process, as the
identity+trust chain starts here.

Story: Creating an account
  As an anonymous user
  I want to be able to create an account
  So that I can be one of the cool kids

  #
  # Account Creation: Get entry form
  #
  Scenario: Anonymous user can start creating an account
    Given an anonymous user
    When  she goes to /signup
    Then  she should be at the 'users/new' page
     And  the page should look AWESOME
     And  she should see a <form> containing a textfield: Login, textfield: Email, password: Password, password: 'Confirm Password', submit: 'Sign up'

  #
  # Account Creation
  #
  Scenario: Anonymous user can create an account
    Given an anonymous user
     And  no user with login: 'Oona' exists
    When  she registers an account as the preloaded 'Oona'
    Then  she should be redirected to the home page
    When  she follows that redirect!
    Then  she should see a notice message 'Thanks for signing up!'
     And  a user with login: 'oona' should exist
     And  the user should have login: 'oona', and email: 'unactivated@example.com'

     And  the user's activation_code should not be nil
     And  the user's activated_at    should     be nil
     And  she should not be logged in


  #
  # Account Creation Failure: Account exists
  #

  Scenario: Anonymous user can not create an account replacing a non-activated account
    Given an anonymous user
     And  a registered user named 'Reggie'
     And  the user has activation_code: 'activate_me', activated_at: nil! 
     And  we try hard to remember the user's updated_at, and created_at
    When  she registers an account with login: 'reggie', password: 'monkey', and email: 'different@example.com'
    Then  she should be at the 'users/new' page
     And  she should     see an errorExplanation message 'Login has already been taken'
     And  she should not see an errorExplanation message 'Email has already been taken'
     And  a user with login: 'reggie' should exist
     And  the user should have email: 'registered@example.com'
     And  the user's activation_code should not be nil
     And  the user's activated_at    should     be nil
     And  the user's created_at should stay the same under to_s
     And  the user's updated_at should stay the same under to_s
     And  she should not be logged in
     
  Scenario: Anonymous user can not create an account replacing an activated account
    Given an anonymous user
     And  an activated user named 'Reggie'
     And  we try hard to remember the user's updated_at, and created_at
    When  she registers an account with login: 'reggie', password: 'monkey', and email: 'reggie@example.com'
    Then  she should be at the 'users/new' page
     And  she should     see an errorExplanation message 'Login has already been taken'
     And  she should not see an errorExplanation message 'Email has already been taken'
     And  a user with login: 'reggie' should exist
     And  the user should have email: 'registered@example.com'

     And  the user's activation_code should     be nil
     And  the user's activated_at    should not be nil
     And  the user's created_at should stay the same under to_s
     And  the user's updated_at should stay the same under to_s
     And  she should not be logged in

  #
  # Account Creation Failure: Incomplete input
  #
  Scenario: Anonymous user can not create an account with incomplete or incorrect input
    Given an anonymous user
     And  no user with login: 'Oona' exists
    When  she registers an account with login: '',     password: 'monkey', password_confirmation: 'monkey' and email: 'unactivated@example.com'
    Then  she should be at the 'users/new' page
     And  she should     see an errorExplanation message 'Login can't be blank'
     And  no user with login: 'oona' should exist
     
  Scenario: Anonymous user can not create an account with no password
    Given an anonymous user
     And  no user with login: 'Oona' exists
    When  she registers an account with login: 'oona', password: '',       password_confirmation: 'monkey' and email: 'unactivated@example.com'
    Then  she should be at the 'users/new' page
     And  she should     see an errorExplanation message 'Password can't be blank'
     And  no user with login: 'oona' should exist
     
  Scenario: Anonymous user can not create an account with no password_confirmation
    Given an anonymous user
     And  no user with login: 'Oona' exists
    When  she registers an account with login: 'oona', password: 'monkey', password_confirmation: ''       and email: 'unactivated@example.com'
    Then  she should be at the 'users/new' page
     And  she should     see an errorExplanation message 'Password confirmation can't be blank'
     And  no user with login: 'oona' should exist
     
  Scenario: Anonymous user can not create an account with mismatched password & password_confirmation
    Given an anonymous user
     And  no user with login: 'Oona' exists
    When  she registers an account with login: 'oona', password: 'monkey', password_confirmation: 'monkeY' and email: 'unactivated@example.com'
    Then  she should be at the 'users/new' page
     And  she should     see an errorExplanation message 'Password doesn't match confirmation'
     And  no user with login: 'oona' should exist
     
  Scenario: Anonymous user can not create an account with bad email
    Given an anonymous user
     And  no user with login: 'Oona' exists
    When  she registers an account with login: 'oona', password: 'monkey', password_confirmation: 'monkey' and email: ''
    Then  she should be at the 'users/new' page
     And  she should     see an errorExplanation message 'Email can't be blank'
     And  no user with login: 'oona' should exist
    When  she registers an account with login: 'oona', password: 'monkey', password_confirmation: 'monkey' and email: 'unactivated@example.com'
    Then  she should be redirected to the home page
    When  she follows that redirect!
    Then  she should see a notice message 'Thanks for signing up!'
     And  a user with login: 'oona' should exist
     And  the user should have login: 'oona', and email: 'unactivated@example.com'

     And  the user's activation_code should not be nil
     And  the user's activated_at    should     be nil
     And  she should not be logged in

     

Story: Activating an account
  As a registered, but not yet activated, user
  I want to be able to activate my account
  So that I can log in to the site

  #
  # Successful activation
  #
  Scenario: Not-yet-activated user can activate her account
    Given a registered user named 'Reggie'
     And  the user has activation_code: 'activate_me', activated_at: nil! 
     And  we try hard to remember the user's updated_at, and created_at
    When  she goes to /activate/activate_me
    Then  she should be redirected to 'login'
    When  she follows that redirect!
    Then  she should see a notice message 'Signup complete!'
     And  a user with login: 'reggie' should exist
     And  the user should have login: 'reggie', and email: 'registered@example.com'
     And  the user's activation_code should     be nil
     And  the user's activated_at    should not be nil
     And  she should not be logged in

  #
  # Unsuccessful activation
  #
  Scenario: Not-yet-activated user can't activate her account with a blank activation code
    Given a registered user named 'Reggie'
     And  the user has activation_code: 'activate_me', activated_at: nil! 
     And  we try hard to remember the user's updated_at, and created_at
    When  she goes to /activate/
    Then  she should be redirected to the home page
    When  she follows that redirect!
    Then  she should see an error  message 'activation code was missing'
     And  a user with login: 'reggie' should exist
     And  the user should have login: 'reggie', activation_code: 'activate_me', and activated_at: nil!
     And  the user's updated_at should stay the same under to_s
     And  she should not be logged in
  
  Scenario: Not-yet-activated user can't activate her account with a bogus activation code
    Given a registered user named 'Reggie'
     And  the user has activation_code: 'activate_me', activated_at: nil! 
     And  we try hard to remember the user's updated_at, and created_at
    When  she goes to /activate/i_haxxor_joo
    Then  she should be redirected to the home page
    When  she follows that redirect!
    Then  she should see an error  message 'couldn\'t find a user with that activation code'
     And  a user with login: 'reggie' should exist
     And  the user should have login: 'reggie', activation_code: 'activate_me', and activated_at: nil!
     And  the user's updated_at should stay the same under to_s
     And  she should not be logged in

