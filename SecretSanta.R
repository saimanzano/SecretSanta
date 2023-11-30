
if (!require("pacman")) install.packages("pacman")
pacman::p_load("blastula", "argparse")

parser <- ArgumentParser(description = cat("Script to do the raffle for a Secret Santa. 
Requirements: 
- email: email address from which to send the emails (needs to be gmail for now)
- participants: CSV file with participants.
  It must contain three fields: name of the person, email address, match ban(s) (e.g so that couples are not together, separated by something other than a comma) in the format name,email,ban.
  If no bans, put the comma and leave blank.
  
Optional: 
- additional: Character string with additional info to put on the body of the message (e.g if there is a budget, a deadline, etc). 

Please note that for the email address you will need the app password. 
See how to obtain it in https://rstudio.github.io/blastula/articles/sending_using_smtp.html

                         "))

## Argument parser ##

parser$add_argument("-e", "--email", type="character", default="secretsantarscript@gmail.com", help="email")
parser$add_argument("-p", "--participants", type="character", default="./participants.csv",help="CSV file with following fields: name, email, bans")
parser$add_argument("-a", "--additional", type="character", default="Have fun!",help="Character string with additional info you want on the email (e.g budget, deadline, etc)")
args <- parser$parse_args()

## Fn to create the file with the email credentials to be able to send emails (will be deleted later) ##

generator_fn <- function(email) {
  create_smtp_creds_file(
  file = "gmail_creds",
  user = "secretsantarscript@gmail.com",
  host = "smtp.gmail.com",
  port = 465,
  use_ssl = TRUE
)
  
}

## Function for the Secret Santa ##
secretsanta <- function(participants, email_addy, body) {
  # Read participants file ## 
  participants <- read.csv(participants, sep=",", header=F, col.names = c("Name", "Address", "Ban"))
  # Shuffle until ready
  finished <- F
  while (finished == F) {
    # Shuffle rows
    shuffle <- participants[sample(1:nrow(participants)), ]
    # Picked person is one from the row below
    shuffle$Picked <- shuffle$Name[c(nrow(shuffle), 1:(nrow(shuffle)-1))]
    # If picked person does not coincide with banned person, finish 
    if (!any(sapply(1:nrow(shuffle), function(x) grepl(shuffle$Picked[x],shuffle$Ban[x])))) {finished <- T}
  }

  print("Pairs picked. Sending emails")
  ## Writing emails ##
  date_time <- add_readable_time()
  for (i in 1:nrow(shuffle)) {
  # Compose message and email  
  msg <- paste0("Hello ", shuffle[i, "Name"], "! You will be ",shuffle[i, "Picked"], "'s Secret Santa! ", body)
  email <- compose_email(body = md(glue::glue(msg)),footer = md(glue::glue("Email sent on {date_time}.")))
  # Send via SMTP
  email |>
  smtp_send(
    to = shuffle[i, "Address"],
    from = email_addy,
    subject = "Secret Santa!",
    credentials = creds_file("gmail_creds")
  )
  }
  # Remove credentials file just in case
file.remove("gmail_creds")
}

if (!file.exists(args$participants)) {
  print("Participants file does not exist. Please specify again.")
} else if (!grepl("@", args$email)) {
  print("Email does not have the correct format. Please specify again.")
} else {
  generator_fn(args$email)
  secretsanta(args$participants, args$email, args$additional)
}




