document.addEventListener("DOMContentLoaded", function () {
    const quizDataElement = document.getElementById("quiz-data");
    const quizData = JSON.parse(quizDataElement.textContent);

    function addOption(questionContainer, option, optionIndex) {
        const optionContainer = document.createElement("div");
        optionContainer.classList.add("option-container");

        const optionInput = document.createElement("input");
        optionInput.type = "text";
        optionInput.name = "questions[][options][][text]";
        optionInput.placeholder = "Alternativ";
        optionInput.value = option.text;
        optionContainer.appendChild(optionInput);

        const correctOptionLabel = document.createElement("label");
        correctOptionLabel.textContent = "Rätt svar";
        optionContainer.appendChild(correctOptionLabel);
        const correctOptionInput = document.createElement("input");
        correctOptionInput.type = "radio";
        correctOptionInput.name = "questions[][correct_option]";
        correctOptionInput.value = optionIndex;
        correctOptionInput.checked = option.is_correct;
        optionContainer.appendChild(correctOptionInput);

        questionContainer.appendChild(optionContainer);
    }

    function addQuestion(questionData) {
        const questionContainer = document.createElement("div");
        questionContainer.classList.add("question-container");

        const questionInput = document.createElement("input");
        questionInput.type = "text";
        questionInput.name = "questions[][text]";
        questionInput.placeholder = "Fråga";
        questionInput.value = questionData.text;
        questionContainer.appendChild(questionInput);

        questionData.options.forEach((option, optionIndex) => {
            addOption(questionContainer, option, optionIndex);
        });

        const addOptionButton = document.createElement("button");
        addOptionButton.type = "button";
        addOptionButton.textContent = "Lägg till alternativ";
        addOptionButton.addEventListener("click", function () {
            addOption(questionContainer, "", questionData.options.length++);
        });
        questionContainer.appendChild(addOptionButton);

        document.getElementById("questions").appendChild(questionContainer);
    }

    quizData.questions.forEach((questionData) => {
        addQuestion(questionData);
    });

    document
        .getElementById("addQuestion")
        .addEventListener("click", function () {
            addQuestion({ text: "", options: [] });
        });
});
