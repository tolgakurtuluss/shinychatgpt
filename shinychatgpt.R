library(shiny)
library(httr)
library(jsonlite)
library(shinyjs)

ui <- fluidPage(
  useShinyjs(),
  tags$head(
    # Theme toggle and styling
    tags$script(HTML("
      function toggleTheme() {
        const isLight = document.body.classList.toggle('light-mode');
        localStorage.setItem('theme', isLight ? 'light' : 'dark');
      }
      document.addEventListener('DOMContentLoaded', function() {
        const theme = localStorage.getItem('theme');
        if (theme === 'light') document.body.classList.add('light-mode');
      });
    ")),
    tags$link(rel = "stylesheet", href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css"),
    tags$style(HTML("
      body {
        font-family: 'Open Sans', sans-serif;
        background-color: #1e1e2f;
        color: white;
        transition: background 0.3s, color 0.3s;
      }
      body.light-mode {
        background-color: #f2f2f2;
        color: black;
      }
      .sidebar-panel {
        background-color: #2b2c3b;
        color: white;
        padding: 25px 20px;
        border-radius: 10px;
      }
      body.light-mode .sidebar-panel {
        background-color: #ffffff;
        color: black;
      }
      .main-chat-panel {
        background-color: #262836;
        border-radius: 10px;
        padding: 20px;
        height: calc(100vh - 40px);
        overflow-y: auto;
      }
      body.light-mode .main-chat-panel {
        background-color: #fafafa;
      }
      .chat-bubble {
        padding: 12px 18px;
        border-radius: 12px;
        margin-bottom: 12px;
        max-width: 95%;
        white-space: pre-wrap;
        font-size: 15px;
        line-height: 1.5;
        box-shadow: 0 1px 4px rgba(0,0,0,0.1);
      }
      
      .chat-bubble-user {
        background-color: #3a3c4a;
        margin-left: auto;
        text-align: left;
      }
      
      .chat-bubble-gpt {
        background-color: #444654;
        margin-right: auto;
        text-align: left;
      }
      
      body.light-mode .chat-bubble-user {
        background-color: #d9e3ea;
      }
      
      body.light-mode .chat-bubble-gpt {
        background-color: #eaeaea;
      }
      .btn-custom {
        background-color: #10a37f;
        color: white;
        border: none;
        border-radius: 5px;
      }
      .btn-custom:hover {
        background-color: #13b08a;
        color: white;
      }
      .form-control {
        background-color: #3d3f50;
        color: white;
        border: 1px solid #666;
        border-radius: 6px;
      }
      .form-control:focus {
        border-color: #10a37f;
        box-shadow: 0 0 5px #10a37f;
      }
      body.light-mode .form-control {
        background-color: white;
        color: black;
        border: 1px solid #ccc;
      }
      #spinner {
        display: none;
        text-align: center;
        margin-top: 10px;
      }
      .spinner-border {
        width: 2rem;
        height: 2rem;
        border: 0.25em solid #10a37f;
        border-right-color: transparent;
        border-radius: 50%;
        animation: spinner-border .75s linear infinite;
      }
      @keyframes spinner-border {
        100% {
          transform: rotate(360deg);
        }
      }
      .modal-content {
        background-color: #2b2c3b;
        color: white;
      }
      .modal-header, .modal-footer {
        border-color: #444;
      }
      .modal-title {
        color: white;
      }
      .modal-body {
        white-space: pre-wrap;
      }
    
      body.light-mode .modal-content {
        background-color: white;
        color: black;
      }
      body.light-mode .modal-title {
        color: black;
      }
    "))
  ),
  
  fluidRow(
    column(
      width = 3,
      div(
        class = "sidebar-panel",
        
        h3("🧠 OpenAI Chat Playground - shinychatgpt"),
        tags$hr(style = "margin-top: 10px; margin-bottom: 20px;"),
        
        actionButton("toggle_theme", NULL, icon = icon("moon"), class = "btn btn-secondary", style = "margin-bottom: 20px;", title = "Toggle Dark/Light Mode"),
        
        textInput("api_key", label = NULL, placeholder = "🔑 Enter OpenAI API Key"),
        tags$small(tags$a(href = "https://platform.openai.com/account/api-keys", target = "_blank", "Get your API Key"), style = "display:block; margin-bottom:15px;"),
        
        h5("⚙️ Model Settings"),
        selectInput("model_name", "Model",
                    choices = c("gpt-4o", "gpt-4-turbo", "gpt-4-0125-preview", "gpt-3.5-turbo-0125", "gpt-3.5-turbo"),
                    selected = "gpt-3.5-turbo"),
        sliderInput("temperature", "Temperature", min = 0.1, max = 1.0, value = 0.7, step = 0.1),
        sliderInput("max_length", "Max Tokens", min = 1, max = 2048, value = 512, step = 1),
        
        h5("🧾 System Prompt"),
        textAreaInput("sysprompt", NULL, height = "80px", placeholder = "e.g. You are a helpful assistant."),
        
        tags$hr(),
        div(style = "display: flex; gap: 10px; flex-wrap: wrap;",
            actionButton("clear_history", NULL, icon = icon("trash"), class = "btn-custom", title = "Clear Chat"),
            downloadButton("download_chat", "Save", class = "btn-custom")
        )
      )
    ),
    column(
      width = 9,
      div(
        class = "main-chat-panel",
        h3("💬 Chat"),
        uiOutput("chat_history"),
        div(id = "spinner", class = "spinner-border", role = "status"),
        tags$hr(),
        fluidRow(
          column(11, textAreaInput("user_message", NULL, placeholder = "Type your message...", width = "100%")),
          column(1, actionButton("send_message", NULL, icon = icon("paper-plane"), class = "btn-custom"))
        )
      )
    )
  )
)

server <- function(input, output, session) {
  chat_data <- reactiveVal(data.frame(source = character(0), message = character(0), stringsAsFactors = FALSE))
  
  observeEvent(input$send_message, {
    req(input$user_message, input$api_key)
    
    new_data <- data.frame(source = "User", message = input$user_message, stringsAsFactors = FALSE)
    chat_data(rbind(chat_data(), new_data))
    disable("send_message")
    runjs("document.getElementById('spinner').style.display = 'block';")
    
    messages <- list()
    if (nzchar(input$sysprompt)) {
      messages <- append(messages, list(list(role = "system", content = input$sysprompt)))
    }
    messages <- append(messages, list(list(role = "user", content = input$user_message)))
    
    body_list <- list(
      model = input$model_name,
      messages = messages,
      temperature = input$temperature,
      max_tokens = input$max_length,
      top_p = 1
    )
    
    json_data <- toJSON(body_list, auto_unbox = TRUE)
    headers <- c("Content-Type" = "application/json", "Authorization" = paste("Bearer", input$api_key))
    
    tryCatch({
      res <- POST(
        url = "https://api.openai.com/v1/chat/completions",
        add_headers(.headers = headers),
        body = json_data,
        encode = "json"
      )
      if (status_code(res) == 200) {
        parsed <- content(res, as = "parsed", type = "application/json")
        output_text <- parsed$choices[[1]]$message$content
        gpt_data <- data.frame(source = "ChatGPT", message = output_text, stringsAsFactors = FALSE)
        chat_data(rbind(chat_data(), gpt_data))
      } else {
        showModal(modalDialog(
          title = paste("API Error — Status:", status_code(res)),
          paste("Message:", content(res, as = "text")),
          easyClose = TRUE
        ))
      }
    }, error = function(e) {
      showModal(modalDialog(
        title = "Request Failed",
        paste("Error:", e$message),
        easyClose = TRUE
      ))
    })
    
    enable("send_message")
    updateTextInput(session, "user_message", value = "")
    runjs("document.getElementById('spinner').style.display = 'none';")
    runjs("window.scrollTo(0, document.body.scrollHeight);")
  })
  
  observeEvent(input$clear_history, {
    chat_data(data.frame(source = character(0), message = character(0), stringsAsFactors = FALSE))
  })
  
  observeEvent(input$toggle_theme, {
    runjs("toggleTheme();")
  })
  
  output$chat_history <- renderUI({
    if (nrow(chat_data()) == 0) {
      return(div(style = "color: #888; font-style: italic;", "No conversation yet."))
    }
    
    lapply(1:nrow(chat_data()), function(i) {
      row <- chat_data()[i, ]
      source_class <- ifelse(row$source == "User", "chat-bubble chat-bubble-user", "chat-bubble chat-bubble-gpt")
      content <- ifelse(nzchar(row$message), row$message, "<i>[No content]</i>")
      
      div(class = source_class,
          HTML(paste0("<b>", row$source, ":</b> ", content)))
    }) %>% tagList()
  })
  
  
  output$download_chat <- downloadHandler(
    filename = function() { "chat_history.txt" },
    content = function(file) {
      chat_history <- paste(chat_data()$source, chat_data()$message, sep = ": ", collapse = "\n")
      writeLines(chat_history, file)
    }
  )
}

shinyApp(ui = ui, server = server)
