# Exercise 01: Build and test a PostgreSQL-backed agent tool backend

### Estimated Duration: 30 Minutes

## Scenario

In this exercise, you will use the prepared lab VM to deploy Azure Database for PostgreSQL Flexible Server, configure Microsoft Entra authentication, complete the Python helper functions that store agent state, create the required database schema, and test the full persistence workflow. By the end of the exercise, you will have a beginner-friendly backend that stores conversations, messages, and task checkpoints so an agent can resume work across sessions.

## Overview

You will work from the preconfigured Windows lab VM associated with **<inject key="DeploymentID" enableCopy="false"></inject>**. First, you will open the starter project and run the provided deployment helper to create an Azure Database for PostgreSQL Flexible Server instance. Next, you will configure Microsoft Entra access, load the generated environment settings, complete the guided Python functions in `agent_tools.py`, create the PostgreSQL schema, run the provided test workflow, and inspect the stored records with SQL.

## Objectives

- Task 1: Prepare starter files and begin deployment
- Task 2: Configure Microsoft Entra access and retrieve connection settings
- Task 3: Complete guided Python tool functions
- Task 4: Create the agent memory schema in PostgreSQL
- Task 5: Test the agent memory workflow
- Task 6: Query persisted context with SQL

## Task 1: Prepare starter files and begin deployment

In this task, you will sign in to Azure, open the prepared starter project on the lab VM, review the deployment helper script, set the resource group and region values, and start the Azure Database for PostgreSQL Flexible Server deployment.

1. Sign in to the lab VM if you are not already connected, and then sign in to the Azure portal at <https://portal.azure.com> using the following credentials:
   - Username: `<inject key="AzureAdUserEmail"></inject>`
   - Password: `<inject key="AzureAdUserPassword"></inject>`

2. Open **Windows PowerShell** or **Windows Terminal** on the lab VM.

3. Sign in to Azure CLI and make sure the correct subscription is selected.

   **Bash**
   ```bash
   az login
   az account set --subscription <inject key="SubscriptionID"></inject>
   az account show --output table
   ```

   **PowerShell**
   ```powershell
   az login
   az account set --subscription <inject key="SubscriptionID"></inject>
   az account show --output table
   ```

   > [!Note]
   > If `az login` opens a browser or device code prompt, complete sign-in with the same lab credentials. If the wrong subscription appears, run `az account list --output table` and then set the subscription again.

4. Open the prepared starter project folder in Visual Studio Code. If the lab desktop includes a shortcut for the downloaded starter files, use it. Otherwise, open the folder where the bootstrap script extracted the project files.

5. In Visual Studio Code, locate and review the deployment helper script that creates the PostgreSQL resources for this lab. Confirm that the script includes values for the Azure region, resource group, server name, and environment output generation.

6. Set the resource group and Azure region values required by the helper script.

   **Bash**
   ```bash
   export RESOURCE_GROUP=rg-agent-memory
   export LOCATION=eastus
   ```

   **PowerShell**
   ```powershell
   $env:RESOURCE_GROUP="rg-agent-memory"
   $env:LOCATION="eastus"
   ```

7. If the deployment helper script requires executable permission or direct invocation, follow the script comments and run it from the project folder.

   **Bash**
   ```bash
   bash ./deploy_postgres.sh
   ```

   **PowerShell**
   ```powershell
   ./deploy_postgres.ps1
   ```

   If your starter files provide a differently named deployment script, run that script instead.

8. Monitor the terminal output and confirm the deployment starts successfully.

   > [!Note]
   > A deployment can take several minutes. If you see an error related to an invalid resource group or unsupported region, correct the `RESOURCE_GROUP` or `LOCATION` value in the script or current shell and rerun the command.

## Task 2: Configure Microsoft Entra access and retrieve connection settings

In this task, you will complete the Microsoft Entra administrator step for the PostgreSQL server, verify that the deployment finished, retrieve the generated environment settings, obtain an access token, and load the values into your terminal session.

1. After the deployment finishes, review the script output and identify the PostgreSQL flexible server name that the helper script created. You will reuse that exact server name in the following commands.

2. Store the server name in a shell variable by replacing `your-server-name` with the actual server name from your deployment output.

   **Bash**
   ```bash
   SERVER_NAME=your-server-name
   RESOURCE_GROUP=${RESOURCE_GROUP:-rg-agent-memory}
   ENTRA_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)
   ```

   **PowerShell**
   ```powershell
   $SERVER_NAME="your-server-name"
   $RESOURCE_GROUP=$env:RESOURCE_GROUP
   if (-not $RESOURCE_GROUP) { $RESOURCE_GROUP="rg-agent-memory" }
   $ENTRA_UPN = az ad signed-in-user show --query userPrincipalName -o tsv
   $ENTRA_OBJECTID = az ad signed-in-user show --query id -o tsv
   ```

3. If the helper script does not already assign a Microsoft Entra administrator, configure it now using your lab account.

   **Bash**
   ```bash
   az postgres flexible-server ad-admin create \
     --resource-group $RESOURCE_GROUP \
     --server-name $SERVER_NAME \
     --display-name "$ENTRA_UPN" \
     --object-id $(az ad signed-in-user show --query id -o tsv)
   ```

   **PowerShell**
   ```powershell
   az postgres flexible-server ad-admin create `
     --resource-group $RESOURCE_GROUP `
     --server-name $SERVER_NAME `
     --display-name "$ENTRA_UPN" `
     --object-id $ENTRA_OBJECTID
   ```

   > [!Note]
   > Microsoft Entra names are case-sensitive when you later connect to PostgreSQL. Use the exact UPN returned by `az ad signed-in-user show`.

4. Verify that the PostgreSQL flexible server is ready.

   **Bash**
   ```bash
   az postgres flexible-server show \
     --resource-group $RESOURCE_GROUP \
     --name $SERVER_NAME \
     --query "state"
   ```

   **PowerShell**
   ```powershell
   az postgres flexible-server show `
     --resource-group $RESOURCE_GROUP `
     --name $SERVER_NAME `
     --query "state"
   ```

5. Locate the environment file or script generated by the deployment helper. Open it and review the values for the PostgreSQL host name, database user name, and any other connection variables the lab provides.

6. Load the generated environment settings into your current shell.

   **Bash**
   ```bash
   source ./.env
   ```

   **PowerShell**
   ```powershell
   Get-Content .\.env | ForEach-Object {
     if ($_ -match '^([^#=]+)=(.*)$') {
       [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
     }
   }
   ```

7. Request a Microsoft Entra access token for Azure Database for PostgreSQL and assign it to the `PGPASSWORD` environment variable.

   **Bash**
   ```bash
   export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
   echo $PGHOST
   echo $PGUSER
   ```

   **PowerShell**
   ```powershell
   $env:PGPASSWORD = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
   Write-Host $env:PGHOST
   Write-Host $env:PGUSER
   ```

   > [!Note]
   > The access token is time-limited. If `psql` or the Python test later fails with an authentication error, request a fresh token and rerun the command.

8. Optionally validate that the expected PostgreSQL connection variables are present in your shell before continuing.

   **Bash**
   ```bash
   env | grep '^PG'
   ```

   **PowerShell**
   ```powershell
   Get-ChildItem Env:PG*
   ```

## Task 3: Complete guided Python tool functions

In this task, you will open `agent_tools.py` and paste in the guided function blocks that create conversations, retrieve conversation history, and save or update task checkpoint state.

1. In Visual Studio Code, open the `agent_tools.py` file from the starter project.

2. Locate the placeholder or TODO section for creating a new conversation record. Paste in the guided code block from the lab instructions.

3. Locate the placeholder or TODO section for retrieving conversation history. Paste in the guided code block from the lab instructions.

4. Locate the placeholder or TODO section for saving or updating a task checkpoint. Paste in the guided code block from the lab instructions.

5. Save the file.

6. Review the SQL statements used by the functions and confirm they match the database objects you will create in the next task:
   - `conversations`
   - `messages`
   - `task_checkpoints`

7. Pay special attention to any upsert logic used for task checkpoints. Confirm that the code expects a unique key on `(conversation_id, task_name)`.

   > [!Note]
   > If the Python file references a column name or table name that does not exactly match the schema you create, the test workflow will fail. Keep the Python code and SQL schema aligned.

## Task 4: Create the agent memory schema in PostgreSQL

In this task, you will connect to PostgreSQL with `psql`, create the `agent_memory` database, create the required tables and indexes, add the unique constraint needed by the upsert logic, and verify that the schema exists.

1. From the project terminal, connect to the default `postgres` database using the environment values you loaded earlier.

   **Bash**
   ```bash
   psql "host=$PGHOST user=$PGUSER dbname=postgres sslmode=require"
   ```

   **PowerShell**
   ```powershell
   psql "host=$env:PGHOST user=$env:PGUSER dbname=postgres sslmode=require"
   ```

2. Create the application database.

   ```sql
   CREATE DATABASE agent_memory;
   ```

3. Exit the current `psql` session.

   ```sql
   \q
   ```

4. Connect to the new `agent_memory` database.

   **Bash**
   ```bash
   psql "host=$PGHOST user=$PGUSER dbname=agent_memory sslmode=require"
   ```

   **PowerShell**
   ```powershell
   psql "host=$env:PGHOST user=$env:PGUSER dbname=agent_memory sslmode=require"
   ```

5. Create the `conversations` table.

   ```sql
   CREATE TABLE conversations (
       id UUID PRIMARY KEY,
       user_id TEXT NOT NULL,
       title TEXT NOT NULL,
       created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   ```

6. Create the `messages` table.

   ```sql
   CREATE TABLE messages (
       id UUID PRIMARY KEY,
       conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
       role TEXT NOT NULL,
       content TEXT NOT NULL,
       created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   ```

7. Create the `task_checkpoints` table.

   ```sql
   CREATE TABLE task_checkpoints (
       id UUID PRIMARY KEY,
       conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
       task_name TEXT NOT NULL,
       status TEXT NOT NULL,
       checkpoint_data JSONB NOT NULL DEFAULT '{}'::jsonb,
       updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   ```

8. Create the indexes used by the lab workflow.

   ```sql
   CREATE INDEX idx_conversations_user_id ON conversations(user_id);
   CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
   CREATE INDEX idx_task_checkpoints_conversation_id ON task_checkpoints(conversation_id);
   ```

9. Add the unique constraint required by the checkpoint upsert logic.

   ```sql
   ALTER TABLE task_checkpoints
   ADD CONSTRAINT uq_task_checkpoints_conversation_task
   UNIQUE (conversation_id, task_name);
   ```

   > [!Note]
   > This unique constraint is required if the Python function uses `ON CONFLICT (conversation_id, task_name)` to update an existing checkpoint. If you skip it, the upsert step will fail.

10. Verify that the tables were created.

    ```sql
    \dt
    ```

11. Optionally inspect the table definitions.

    ```sql
    \d conversations
    \d messages
    \d task_checkpoints
    ```

12. Leave the `psql` session open for the next task, or exit with `\q` if you prefer to return to the shell.

## Task 5: Test the agent memory workflow

In this task, you will create a Python virtual environment, install the provided dependencies, run the supplied test script, and confirm that the backend writes conversation, message, and checkpoint records successfully.

1. Return to the project folder in your terminal if needed.

2. Create a Python virtual environment.

   **Bash**
   ```bash
   python -m venv .venv
   ```

   **PowerShell**
   ```powershell
   python -m venv .venv
   ```

3. Activate the virtual environment.

   **Bash**
   ```bash
   source .venv/Scripts/activate
   ```

   **PowerShell**
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```

4. Install the dependencies provided with the starter project.

   **Bash**
   ```bash
   pip install -r requirements.txt
   ```

   **PowerShell**
   ```powershell
   pip install -r requirements.txt
   ```

5. If your `PGPASSWORD` token was set earlier, refresh it now so it is still valid before running the test.

   **Bash**
   ```bash
   export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
   ```

   **PowerShell**
   ```powershell
   $env:PGPASSWORD = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
   ```

6. Run the provided test script.

   **Bash**
   ```bash
   python test_workflow.py
   ```

   **PowerShell**
   ```powershell
   python .\test_workflow.py
   ```

7. Review the output and confirm that the workflow completes successfully. You should see evidence that the application can:
   - Create a conversation
   - Store one or more messages
   - Insert or update task checkpoint data
   - Read conversation history back from the database

   > [!Note]
   > If the script fails with a connection or authentication error, first confirm that `.env` was loaded and that `PGPASSWORD` contains a fresh token. If the script fails during checkpoint updates, verify that the unique constraint on `(conversation_id, task_name)` exists.

## Task 6: Query persisted context with SQL

In this task, you will reconnect to the `agent_memory` database, query stored conversations for a user, retrieve recent messages, inspect checkpoint records, and summarize how persisted data supports agent continuity across sessions.

1. Connect to the `agent_memory` database if you are not already connected.

   **Bash**
   ```bash
   psql "host=$PGHOST user=$PGUSER dbname=agent_memory sslmode=require"
   ```

   **PowerShell**
   ```powershell
   psql "host=$env:PGHOST user=$env:PGUSER dbname=agent_memory sslmode=require"
   ```

2. Query the stored conversations.

   ```sql
   SELECT id, user_id, title, created_at
   FROM conversations
   ORDER BY created_at DESC;
   ```

3. Retrieve recent messages.

   ```sql
   SELECT conversation_id, role, content, created_at
   FROM messages
   ORDER BY created_at DESC
   LIMIT 10;
   ```

4. Inspect saved task checkpoints.

   ```sql
   SELECT conversation_id, task_name, status, checkpoint_data, updated_at
   FROM task_checkpoints
   ORDER BY updated_at DESC;
   ```

5. If you want to inspect data for one specific conversation, copy one of the `conversation_id` values returned by the first query and use it in a filtered query.

   ```sql
   SELECT role, content, created_at
   FROM messages
   WHERE conversation_id = 'replace-with-a-real-conversation-id-from-your-query-results'
   ORDER BY created_at;
   ```

6. Review the returned rows and identify how the persisted records support continuity:
   - `conversations` stores the high-level interaction record.
   - `messages` stores the running conversation history.
   - `task_checkpoints` stores resumable task state for in-progress or completed work.

   > [!Note]
   > If the queries return no rows, rerun `test_workflow.py` and confirm it completed successfully before reconnecting to the database.

## Summary

In this exercise, you deployed Azure Database for PostgreSQL Flexible Server from the lab VM, configured Microsoft Entra access, loaded the generated connection settings, completed the guided Python functions in `agent_tools.py`, created the `agent_memory` database schema, ran the provided test workflow, and queried the persisted data with SQL. You now have a working beginner-friendly pattern for storing agent conversation context and task state in PostgreSQL so an agent can continue work across sessions.
