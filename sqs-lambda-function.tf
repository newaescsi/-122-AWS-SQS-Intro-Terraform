# provider "aws" {
#   region = "eu-central-1" # Ändere dies auf deine gewünschte Region
# }

provider "aws" {
  region = "eu-central-1" # Ändere dies auf deine gewünschte Region
  #access_key = ""
  #secret_key = ""
}


# Erstellen der SQS-Warteschlange
resource "aws_sqs_queue" "my_queue" {
  name                      = "MySQSQueue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600  # 4 Tage
  visibility_timeout_seconds = 30
  receive_wait_time_seconds = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn    = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount        = 5
  })
}

# Erstellen der Dead-Letter-Warteschlange
resource "aws_sqs_queue" "dead_letter_queue" {
  name = "DeadLetterQueue"
}

# Erstellen der Queue Policy
resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.my_queue.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "1",
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.my_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sqs_queue.my_queue.arn
          }
        }
      }
    ]
  })
}

# Erstellen der Lambda-Funktion
# resource "aws_lambda_function" "sqs_lambda_function" {
#   function_name = "SQSLambdaFunction"
#   handler      = "index.handler"
#   runtime      = "nodejs14.x" # Ändere dies auf die gewünschte Node.js-Version
#   role = aws_iam_role.lambda_execution_role.arn
#   source_code_hash = filebase64sha256("lambda-function.zip") # Passe den Pfad zur Lambda-Code-Zip-Datei an
# }

resource "aws_lambda_function" "sqs_lambda_function" {
  function_name = "SQSLambdaFunction"
  handler      = "index.handler"
  runtime      = "nodejs14.x" # Ändere dies auf die gewünschte Node.js-Version
  role         = aws_iam_role.lambda_execution_role.arn

  # Verwende den `filename`-Parameter, um den Pfad zur Lambda-Code-Zip-Datei anzugeben
  filename     = "lambda_function.zip" # Passe den Pfad zur Lambda-Code-Zip-Datei an
}



# Erstellen der Lambda Execution Role mit Zugriff zur SQS-Warteschlange
resource "aws_iam_role" "lambda_execution_role" {
  name = "LambdaExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "sqs_access_policy" {
  name        = "SQSAccessPolicy"
  description = "Policy for SQS access"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "sqs:*",
        Effect   = "Allow",
        Resource = aws_sqs_queue.my_queue.arn
      }
    ]
  })
}

# Hinzufügen der `name`-Eigenschaft für `aws_iam_policy_attachment`
resource "aws_iam_policy_attachment" "sqs_access_attachment" {
  name = "sqs-access-attachment"  # Hier einen Namen festlegen
  policy_arn = aws_iam_policy.sqs_access_policy.arn
  roles = [aws_iam_role.lambda_execution_role.name]
}

# Konfigurieren des Lambda-Trigger für die SQS-Warteschlange
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn  = aws_sqs_queue.my_queue.arn
  function_name     = aws_lambda_function.sqs_lambda_function.function_name
  batch_size        = 5
  starting_position = "LATEST"
}

# Terraform Output für die Queue-URL
output "queue_url" {
  value = aws_sqs_queue.my_queue.id
}
