library(shiny)
library(httr)
library(stringr)

ui <- fluidPage(
  div(
    titlePanel("ChatGPT Clone with Shiny"),
    style = "color: white; background-color: #3d3f4e"
  ),
  sidebarLayout(
    sidebarPanel(
      h3("Welcome to the OpenAI Playground - ChatGPT Clone with Shiny!"),
      p("This application allows you to chat with an OpenAI GPT model and explore its capabilities. Simply use your own API keys with adding below."),
      textInput("api_key", "API Key", "sk-PLACEYOUROWNAPIKEYHERE"),
      tags$p("Find your own OpenAI API:", 
             tags$a(href = "https://platform.openai.com/account/api-keys", target="_blank", "https://platform.openai.com/account/api-keys")
      ),tags$hr(),
      selectInput("model_name", "Model Name",
                  choices = c("gpt-4", "gpt-4-0314", "gpt-3.5-turbo-0301", "gpt-3.5-turbo"), selected = "gpt-3.5-turbo"),
      tags$hr(),
      sliderInput("temperature", "Temperature", min = 0.1, max = 1.0, value = 0.7, step = 0.1),
      sliderInput("max_length", "Maximum Length", min = 1, max = 2048, value = 512, step = 1),
      tags$hr(),
      textAreaInput(inputId = "sysprompt", label = "SYSTEM PROMPT",height = "200px", placeholder = "You are a helpful assistant."),
      tags$hr(),
      tags$div(
        style="text-align:center; margin-top: 15px; color: white; background-color: #FFFFFF",
        a(href="https://github.com/tolgakurtuluss/shinychatgpt", target="_blank",
          img(src="https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png", height="30px"),
          "View source code on Github"
        )
      ),
      style = "background-color: #1a1b1f; color: white"
    )
    ,
    mainPanel(
      tags$style(type = "text/css", ".shiny-output-error {visibility: hidden;}"),
      tags$style(type = "text/css", ".shiny-output-error:before {content: ' Check your inputs or API key';}"),
      tags$style(type = "text/css", "label {font-weight: bold;}"),
      fluidRow(
        column(12,tags$h3("Chat History"),tags$hr(),uiOutput("chat_history"),tags$hr())
      ),
      fluidRow(
        column(11,textAreaInput(inputId = "user_message", placeholder = "Enter your message:", label="USER PROMPT", width = "100%")),
        column(1,actionButton("send_message", "Send",icon = icon("play"),height = "350px"))
      ),style = "background-color: #00A67E")
  ),style = "background-color: #3d3f4e")

server <- function(input, output, session) {
  chat_data <- reactiveVal(data.frame())
  
  observeEvent(input$send_message, {
    if (input$user_message != "") {
      new_data <- data.frame(source = "User", message = input$user_message, stringsAsFactors = FALSE)
      chat_data(rbind(chat_data(), new_data))
      
      gpt_res <- call_gpt_api(input$api_key, input$user_message, input$model_name, input$temperature, input$max_length, input$sysprompt)
      
      if (!is.null(gpt_res)) {
        gpt_data <- data.frame(source = "ChatGPT", message = gpt_res, stringsAsFactors = FALSE)
        chat_data(rbind(chat_data(), gpt_data))
      }
      updateTextInput(session, "user_message", value = "")
    }
  })
  
  call_gpt_api <- function(api_key, prompt, model_name, temperature, max_length, sysprompt) {
    response <- httr::POST(
      url = "https://api.openai.com/v1/chat/completions", 
      add_headers(Authorization = paste("Bearer", api_key)),
      content_type("application/json"),
      encode = "json",
      body = list(
        model = model_name,
        messages = list(
          list(role = "user", content = prompt),
          list(role = "system", content = sysprompt)
        ),
        temperature = temperature,
        max_tokens = max_length
      )
    )
    return(str_trim(content(response)$choices[[1]]$message$content))
  }
  
  output$chat_history <- renderUI({
    chatBox <- lapply(1:nrow(chat_data()), function(i) {
      tags$div(class = ifelse(chat_data()[i, "source"] == "User", "alert alert-secondary", "alert alert-success"),
               HTML(paste0("<b>", chat_data()[i, "source"], ":</b> ", chat_data()[i, "message"])))
    })
    do.call(tagList, chatBox)
  })
  
  observeEvent(input$download_button, {
    if (nrow(chat_data()) > 0) {
      session$sendCustomMessage(type = "downloadData", message = "download_data")
    }
  })
}
shinyApp(ui = ui, server = server)
