require 'sinatra'
require "sinatra/reloader" if development?
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './models/model.rb'
include Model

enable :sessions
set :session_secret, "mysupersecretkey"
set :sessions, :expire_after => 2592000


set :port, 8040
set :public_folder, 'public'



before do
    session[:request_times] ||= {}
  
    # Use string version of request.path
    path = request.path.to_s

    if path == "/error"
        return
    end

    session[:request_times][path] ||= []
    
    # Remove any request times older than 1 minute
    session[:request_times][path].delete_if { |time| Time.now - Time.parse(time) > 60 }
  
    if session[:request_times][path].size >= 12
        redirect("/error?from=#{path}")
    end
  
    session[:request_times][path].push(Time.now.to_s)
end
  

before do
    if session[:user_id]
        @user = get_user_by_id(session[:user_id])
        @is_admin = is_admin(session[:user_id])
        
    else
        @user = nil
    end
end


before("/app*") do
    if !session[:user_id]
        redirect('/login')
    end
end

before("/app/admin*") do
    if !session[:user_id]
        redirect('/login')
    end
    
    if !is_admin(session[:user_id])
        redirect('/app')
    end
end

# Display an error page
#
get("/error") do
    @from = params[:from]
    slim(:error)
end

# Logout the user and redirect to home page
#

get("/logout") do
    session[:user_id] = nil
    redirect('/')
end

# Displays all quizzes of the current logged in user
#
# @see get_user_by_id
# @see get_all_quizzes
# @see get_likes_count
# @see has_user_liked
get('/app') do
    user_id = session[:user_id]
    @user = get_user_by_id(user_id)
    @quizzes = get_all_quizzes()

    if !@quizzes
        @quizzes = []
    end

    @quizzes.each do |quiz|
        quiz['likes'] = get_likes_count(quiz['id'])
        quiz['is_liked'] = has_user_liked(user_id, quiz['id'])
    end

    p @quizzes

    slim(:"app/index")
end

# Redirects to '/app' or '/login' based on whether user is logged in
#
get('/') do
    user_id = session[:user_id]

    if user_id 
        redirect('/app')
    else
        redirect('/login')
    end
end

# Displays a register form with potential error messages
#
get('/register') do  
    @errors = session.delete(:error)
    slim(:register)
end

# Displays a login form with potential error messages
#
get('/login') do
    if session[:user_id]
        redirect('/app')
    end
    @errors = session.delete(:error)
    slim(:login)
end

# Displays user's profile based on id
#
# @param [Integer] :id, The ID of the user
#
# @see get_user_by_id
# @see get_user_quizzes
get("/app/user/:id") do
    user_id = params[:id]
    @user = get_user_by_id(user_id)
    @quizzes = get_user_quizzes(user_id)

    @quizzes.each do |quiz|
        quiz['likes'] = get_likes_count(quiz['id'])
        quiz['is_liked'] = has_user_liked(session[:user_id], quiz['id'])
        p has_user_liked(user_id, quiz['id'])
    end
    
    slim(:"app/user/show")
end

# Begins quiz play based on quiz id
#
# @param [Integer] :id, The ID of the quiz
#
# @see get_quiz_by_id
get("/app/quiz/play/:id") do
    quiz_id = params[:id]
    
    @quiz = get_quiz_by_id(quiz_id)
    slim(:"app/quiz/play")
end

# Displays a form to edit a quiz based on quiz id
#
# @param [Integer] :id, The ID of the quiz
#
# @see get_quiz_by_id
get("/app/quiz/edit/:id") do
    quiz_id = params[:id]
    @quiz = get_quiz_by_id(quiz_id) 

    if !@quiz
        redirect back
    end

    if @quiz['creator_id'] != session[:user_id]
        redirect("/app/quizzes")
    end

    @quiz['questions'].each do |question|
        question['options'].each do |option|
            option['is_correct'] = option['is_correct'] == 1
        end
    end


    slim(:"app/quiz/edit")
end

# Toggles like status for a quiz based on quiz id
#
# @param [Integer] :id, The ID of the quiz
#
# @see delete_like
# @see create_like

post("/app/quiz/like/toggle/:id") do
    quiz_id = params[:id]
    user_id = session[:user_id]

    if(has_user_liked(user_id, quiz_id))
        delete_like(user_id, quiz_id)
    else 
        create_like(user_id, quiz_id)
    end

    redirect back
end

# Processes submitted answers for a quiz based on quiz id
#
# @param [Integer] :id, The ID of the quiz
#
# @see get_quiz_by_id

post("/app/quiz/play/:id") do
    
    quiz_id = params[:id]
    submitted_answers = params[:answer]

    quiz = get_quiz_by_id(quiz_id) 

    @correct_answers = 0

    quiz['questions'].each do |question|
        question_id = question['id'].to_s
        correct_option = question['options'].find { |option| option['is_correct'] == 1 }

        # Check if the submitted answer is correct
        if submitted_answers[question_id] == correct_option['id'].to_s
        @correct_answers += 1
        end
    end

    @total_questions = quiz['questions'].length
    @score_percentage = (@correct_answers.to_f / @total_questions) * 100
    
    slim(:"app/quiz/result")
end

# Deletes a quiz based on quiz id
#
# @param [Integer] :id, The ID of the quiz
#
# @see delete_quiz

get("/app/quiz/:id/delete") do
    quiz_id = params[:id]
    delete_quiz(quiz_id, session[:user_id])
    redirect back
end



post("/login") do
    email = params["email"]
    password = params["password"]

    user = authenticate_user(email, password)

    if !user
        session[:error] = "Felaktig e-postadress eller lösenord."
        redirect('/login')
    end


    session[:user_id] = user["id"]
    redirect('/app')

end

post('/register') do
    email = params["email"]
    password = params["password"]
    password_confirmation = params["password_confirmation"]
    username = params["username"]

    
    if !validate_user_input(username, password)
        session[:error] = "användarnamn eller lösenord är för kort eller för långt."
        redirect('/register')
    end
    
    if password != password_confirmation
        session[:error] = "Lösenorden matchar inte."
        redirect('/register')
    end

    if !validate_email(email)
        session[:error] = "E-postadressen är inte giltig."
        redirect('/register')
    end



    user_already_exists = get_user_by_email(email)

    if user_already_exists
        session[:error] = "En användaren med den e-postadressen finns redan."
        redirect('/register')
    end

    user_id = create_user(username, email, password)

    session[:user_id] = user_id

    redirect('/app')
end

get("/app/quiz/create") do 
    slim(:"app/quiz/create")
end

get("/app/quizzes") do
    @quizzes = get_user_quizzes(session[:user_id])
    p @quizzes
    slim(:"app/quizzes/show")
end

post("/quiz/create") do
    title = params[:name]
    description = params[:description]
  
    creator_id = session[:user_id]
  
    questions = params[:questions].values.map do |question|
      text = question[:text]
      
      correct_option = question[:correct_option].to_i
  
      options = question[:options].map.with_index do |option, index|
        {
          text: option[1],
          is_correct: (index == correct_option) ? 1 : 0,
        }
      end
  
      {
        text: text,
        options: options,
      }
    end.reject { |question| 
        question[:text].strip.empty? || 
        question[:options].all? { |option| option[:text].strip.empty? } ||
        question[:options].none? { |option| option[:is_correct] == 1 }
    } 

    create_quiz(title, description, creator_id, questions)
  
    redirect("/app/quizzes")
end


  
post("/app/quiz/edit/:id") do
    title = params[:name]
    description = params[:description]
    quiz_id = params[:quiz_id]
  
    questions = params[:questions].values.map do |question|
      text = question[:text]
      question_id = question[:id]
        
      correct_option = question[:correct_option].to_i
  
      options = question[:options].map.with_index do |option, index|
        {
          id: option[1][:id],
          text: option[1][:text],
          is_correct: (index == correct_option) ? 1 : 0,
        }
      end
  
      {
        id: question_id,
        text: text,
        options: options,
      }
    end.reject { |question| 
        question[:text].strip.empty? || 
        question[:options].all? { |option| option[:text].strip.empty? } ||
        question[:options].none? { |option| option[:is_correct] == 1 }
    } 
  
    update_quiz(quiz_id, title, description, questions)
  
    redirect("/app/quizzes")
end
  


get("/app/admin") do
    @users = get_all_users()
    @users.each do |user|
        user["password"] = "********"
        if user["id"] == session[:user_id]
            user["role"] = "you"
        end
    end
    slim(:"app/admin/index")
end


post("/app/admin/user/update-role/:user_id") do
    user_id = params["user_id"]
    request_data = JSON.parse(request.body.read)
    role = request_data["role"]
    update_user_role(user_id, role.to_i)
    redirect("/app/admin")
end
