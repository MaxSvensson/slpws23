require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'


def connect_to_db()
    db = SQLite3::Database.new("db/quiz.db")
    db.results_as_hash = true
    return db
end


def create_user(username, email, password)
    db = connect_to_db()
    password_digest = BCrypt::Password.create(password)
    db.execute("INSERT INTO users (username, email, password) VALUES (?, ?, ?)", [username, email, password_digest])
end


def get_user_by_id(id)
    db = connect_to_db()
    return db.execute("SELECT * FROM users WHERE id = ?", [id]).first
end

def get_user_by_email(email)
    db = connect_to_db()
    return db.execute("SELECT * FROM users WHERE email = ?", [email]).first
end

def authenticate_user(email, password)
    user = get_user_by_email(email)
    if user && BCrypt::Password.new(user["password"]) == password
        return user
    else
        return nil
    end
end

def login_user()

def create_post(title, description, creator_id, questions)
    db = connect_to_db()
    
    # Start a transaction
    db.transaction
    
    # Insert the quiz
    db.execute("INSERT INTO quizzes (title, description, creator_id) VALUES (?, ?, ?)", [title, description, creator_id])
    quiz_id = db.last_insert_row_id
    
    # Insert the questions and options
    questions.each do |question|
        text = question[:text]
        options = question[:options]
    
        # Insert the question
        db.execute("INSERT INTO questions (text, quiz_id) VALUES (?, ?)", [text, quiz_id])
        question_id = db.last_insert_row_id
    
        # Insert the options
        options.each do |option|
        option_text = option[:text]
        is_correct = option[:is_correct]
        db.execute("INSERT INTO options (text, is_correct, question_id) VALUES (?, ?, ?)", [option_text, is_correct, question_id])
        end
    end
    
    # Commit the transaction
    db.commit
end
      