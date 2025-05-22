library(shiny)
library(httr)
library(stringr)
library(shinyjs)
library(jsonlite)

ui <- fluidPage(
  useShinyjs(),
  div(
    titlePanel("ChatGPT Clone with Shiny"),
    style = "color: white; background-color: #3d3f4e"
  ),
  sidebarLayout(
    sidebarPanel(
      h3("OpenAI Playground - ChatGPT Clone"),
      p("Chat with an OpenAI GPT model. Add your API key below."),
      textInput("api_key", "API Key", "sk-PLACEYOUROWNAPIKEYHERE"),
      tags$p("Get your API key: ", 
             tags$a(href = "https://platform.openai.com/account/api-keys", target="_blank", "OpenAI API Keys")
      ),
      tags$hr(),
      selectInput("model_name", "Model Name",
                  choices = c("gpt-4o", "gpt-4-turbo", "gpt-4-turbo-preview", "gpt-4-0125-preview", "gpt-4-1106-preview", "gpt-4", "gpt-4-0613", "gpt-3.5-turbo", "gpt-3.5-turbo-0125", "gpt-3.5-turbo-1106"), selected = "gpt-3.5-turbo"),
      sliderInput("temperature", "Temperature", min = 0.1, max = 1.0, value = 0.7, step = 0.1),
      sliderInput("max_length", "Maximum Length", min = 1, max = 2048, value = 512, step = 1),
      tags$hr(),
      textAreaInput("sysprompt", "SYSTEM PROMPT", height = "100px", placeholder = "You are a helpful assistant."),
      actionButton("clear_history", "Clear Chat History", icon = icon("trash"), style = "margin-top: 10px;"),
      downloadButton("download_chat", "Download Chat History", icon = icon("download"), style = "margin-top: 10px;"),
      tags$hr(),
      div(
        style="text-align:center; margin-top: 15px;",
        a(href="https://github.com/tolgakurtuluss/shinychatgpt", target="_blank",
          img(src="https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png", height="30px"),
          "Source on Github"
        )
      ),
      style = "background-color: #1a1b1f; color: white"
    ),
    mainPanel(
      tags$style(type = "text/css", ".shiny-output-error {visibility: hidden;}"),
      tags$style(type = "text/css", ".shiny-output-error:before {content: 'Check your inputs or API key';}"),
      tags$style(type = "text/css", "label {font-weight: bold;}"),
      fluidRow(
        column(12, tags$h3("Chat History"), tags$hr(), uiOutput("chat_history"), tags$hr())
      ),
      fluidRow(
        column(11, textAreaInput("user_message", "USER PROMPT", placeholder = "Enter your message:", width = "100%")),
        column(1, actionButton("send_message", "Send", icon = icon("paper-plane")))
      ),
      style = "background-color: #00A67E; padding: 15px; color: white; border-radius: 10px;"
    )
  ),
  tags$script(HTML("
    Shiny.addCustomMessageHandler('downloadData', function(message) {
      var link = document.createElement('a');
      link.href = 'data:text/plain;charset=utf-8,' + encodeURIComponent(message);
      link.download = 'chat_history.txt';
      link.click();
    });
  "))
)

server <- function(input, output, session) {
  chat_data <- reactiveVal(data.frame(source = character(0), message = character(0), stringsAsFactors = FALSE))
  
  observeEvent(input$send_message, {
    if (input$user_message != "" && input$api_key != "") {
      new_data <- data.frame(source = "User", message = input$user_message, stringsAsFactors = FALSE)
      chat_data(rbind(chat_data(), new_data))
      
      disable("send_message")
      gpt_res <- call_gpt_api(input$api_key, input$user_message, input$model_name, input$temperature, input$max_length, input$sysprompt)
      
      if (!is.null(gpt_res)) {
        gpt_data <- data.frame(source = "ChatGPT", message = gpt_res, stringsAsFactors = FALSE)
        chat_data(rbind(chat_data(), gpt_data))
      } else {
        showModal(modalDialog(
          title = "Error",
          "Failed to get response. Check your API key or input.",
          easyClose = TRUE,
          footer = NULL
        ))
      }
      enable("send_message")
      updateTextInput(session, "user_message", value = "")
    }
  })
  
  observeEvent(input$clear_history, {
    chat_data(data.frame(source = character(0), message = character(0), stringsAsFactors = FALSE))
  })
  
  call_gpt_api <- function(api_key, prompt, model_name, temperature, max_length, sysprompt) {
    tryCatch({
      response <- POST(
        url = "https://api.openai.com/v1/chat/completions", 
        add_headers(Authorization = paste("Bearer", api_key)),
        content_type("application/json"),
        encode = "json",
        body = list(
          model = model_name,
          messages = list(
            list(role = "system", content = sysprompt),
            list(role = "user", content = prompt)
          ),
          temperature = temperature,
          max_tokens = max_length
        )
      )
      if (status_code(response) == 200) {
        content(response)$choices[[1]]$message$content %>% str_trim()
      } else {
        NULL
      }
    }, error = function(e) {
      NULL
    })
  }
  
  output$chat_history <- renderUI({
  lapply(1:nrow(chat_data()), function(i) {
    div(class = ifelse(chat_data()[i, "source"] == "User", "alert alert-secondary", "alert alert-success"),
        HTML(paste0("<b>", chat_data()[i, "source"], ":</b> ", chat_data()[i, "message"])))
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
