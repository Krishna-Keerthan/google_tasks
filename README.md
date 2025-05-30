# 🛠️ How to Use (Cloud Shell or Terminal)
Follow these steps to run the script manually in your Google Cloud Shell or terminal:

## 1. Open Cloud Shell or your local terminal
Make sure you have the Google Cloud SDK (gcloud) installed and authenticated if running locally.

## 2. Create the script file

```bash
nano test1_create_vm.sh 

```

## 3. Paste the script content
Paste the full content of test1_create_vm.sh into the nano editor.

Replace:

```bash
PROJECT_ID="your-project-id"

```

with your actual GCP project ID.
Save and exit (Press CTRL+X, then Y and finally Enter).

## 4. Make the script executable
```bash
chmod +x test1_create_vm.sh
```

## 5. Run the script
```bash
./test1_create_vm.sh

```
