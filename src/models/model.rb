require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'jwt'

module Model

    def connect_to_db()
        db = SQLite3::Database.new("db/quiz.db")
        db.results_as_hash = true
        return db
    end


    def validate_user_input (username, password)
        if username.length < 3 || username.length > 20
            return false
        end
      
        if password.length < 3 || password.length > 20
            return false
        end
        return true
    end

    def validate_email(email) 
        /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i.match?(email)
    end

    def create_user(username, email, password)
        db = connect_to_db()
        password_digest = BCrypt::Password.create(password)
        db.execute("INSERT INTO users (username, email, password) VALUES (?, ?, ?)", [username, email, password_digest])
        return new_user_id = db.last_insert_row_id
    end


    def get_user_by_id(id)
        db = connect_to_db()
        return db.execute("SELECT * FROM users WHERE id = ?", [id]).first
    end

    def get_user_by_email(email)
        db = connect_to_db()
        return db.execute("SELECT * FROM users WHERE email = ?", [email]).first
    end

    def compare_passwords(password, password_digest)

        return BCrypt::Password.new(password_digest) == password
    end

    def authenticate_user(email, password)
        user = get_user_by_email(email)
        p user
        if user && BCrypt::Password.new(user["password"]) == password
            return user
        else
            return nil
        end
    end


    def has_user_liked(user_id, quiz_id)
        db = connect_to_db()
        result = db.execute("SELECT COUNT(*) FROM likes WHERE user_id = ? AND quiz_id = ?", [user_id, quiz_id])
        return result[0][0] > 0
    end

    def create_like(user_id, quiz_id)
        db = connect_to_db()
    
    return db.execute("INSERT INTO likes (user_id, quiz_id) VALUES (?, ?)", [user_id, quiz_id])
    end

    def delete_like(user_id, quiz_id)
        db = connect_to_db()
        return db.execute("DELETE FROM likes WHERE user_id = ? AND quiz_id = ?", [user_id, quiz_id])
    end

    def get_likes_count(quiz_id)
        db = connect_to_db()

        result = db.execute("SELECT COUNT(*) FROM likes WHERE quiz_id = ?", [quiz_id])
        return result[0][0]
    end
    


    # def structure_questions(question) do 
    #     questions = params[:questions].map do |question|
    #         text = question[:text]
    #         correct_option = question[:correct_option].to_i
        
    #         options = question[:options].map.with_index do |option, index|
    #           {
    #             text: option[:text],
    #             is_correct: (index == correct_option) ? 1 : 0,
    #           }
    #         end
        
    #         {
    #           text: text,
    #           options: options,
    #         }
    #       end

    #       return questions
    # end

    def get_user_quizzes(user_id) 
        db = connect_to_db()
        return db.execute("SELECT * FROM quizzes WHERE creator_id = ?", [user_id])
    end

    def delete_quiz(quiz_id, user_id)
        db = connect_to_db()
        if is_admin(user_id)
            return db.execute("DELETE FROM quizzes WHERE id = ?", [quiz_id])
        end 
        db.execute("DELETE FROM quizzes WHERE id = ? AND creator_id = ?", [quiz_id, user_id])
        db.execute("DELETE FROM questions WHERE quiz_id = ?", [quiz_id])
        return db.execute("DELETE FROM options WHERE question_id = ?", [quiz_id])
    end

    def get_quiz_by_id(quiz_id)
        db = connect_to_db()
        quiz = db.execute("SELECT * FROM quizzes WHERE id = ?", [quiz_id]).first
        if quiz == nil
            return nil
        end
        questions = db.execute("SELECT * FROM questions WHERE quiz_id = ?", [quiz_id])
        questions.each do |question|
            question_id = question["id"]
            options = db.execute("SELECT * FROM options WHERE question_id = ?", [question_id])
            question["options"] = options
        end
        quiz["questions"] = questions
        return quiz
    end
        
    def get_all_quizzes()
        db = connect_to_db()
        quizzes = db.execute("SELECT quizzes.*, COUNT(likes.id) AS likes_count FROM quizzes LEFT JOIN likes ON quizzes.id = likes.quiz_id GROUP BY quizzes.id")
        quizzes.each do |quiz|
        user = get_user_by_id(quiz["creator_id"])
        quiz["creator"] = user
        end
        return quizzes
    end

    def get_all_users()
        db = connect_to_db()
        return db.execute("SELECT * FROM users")
    end

    def create_quiz(title, description, creator_id, questions)
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

    def update_quiz(quiz_id, title, description, questions)
        db = connect_to_db()

        # Start a transaction
        db.transaction

        # Update the quiz
        db.execute("UPDATE quizzes SET title = ?, description = ? WHERE id = ?", [title, description, quiz_id])

        # Update the questions and options
        questions.each do |question|
            text = question[:text]
            question_id = question[:id].empty? ? nil : question[:id]
            options = question[:options]

            if question_id.nil?
                # If question ID is nil, insert a new question
                db.execute("INSERT INTO questions (text, quiz_id) VALUES (?, ?)", [text, quiz_id])
                question_id = db.last_insert_row_id  # Get the ID of the newly inserted question
            else
                # Otherwise, update the existing question
                db.execute("UPDATE questions SET text = ? WHERE id = ?", [text, question_id])
            end

            options.each do |option|
                option_text = option[:text]
                is_correct = option[:is_correct]
                option_id = option[:id].empty? ? nil : option[:id]

                if option_id.nil?
                    # If option ID is nil, insert a new option
                    db.execute("INSERT INTO options (text, is_correct, question_id) VALUES (?, ?, ?)", [option_text, is_correct, question_id])
                else
                    # Otherwise, update the existing option
                    db.execute("UPDATE options SET text = ?, is_correct = ? WHERE id = ?", [option_text, is_correct, option_id])
                end
            end
        end

        # Commit the transaction
        db.commit
    end

    


    def update_user_role(user_id, role)
        db = connect_to_db()
        db.execute("UPDATE users SET role = ? WHERE id = ?", [role, user_id])
    end


    def is_admin(user_id)
        user = get_user_by_id(user_id)
        return user["role"] == 1
    end

end