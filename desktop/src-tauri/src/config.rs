use tauri_plugin_store::StoreExt;

const STORE_PATH: &str = ".ple7-config.json";
const TOKEN_KEY: &str = "auth_token";

#[tauri::command]
pub async fn store_token(app: tauri::AppHandle, token: String) -> Result<(), String> {
    let store = app
        .store(STORE_PATH)
        .map_err(|e| format!("Failed to open store: {}", e))?;

    store
        .set(TOKEN_KEY, serde_json::json!(token));

    store
        .save()
        .map_err(|e| format!("Failed to save store: {}", e))?;

    Ok(())
}

#[tauri::command]
pub async fn get_stored_token(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let store = app
        .store(STORE_PATH)
        .map_err(|e| format!("Failed to open store: {}", e))?;

    match store.get(TOKEN_KEY) {
        Some(value) => {
            let token = value
                .as_str()
                .ok_or("Token is not a string")?
                .to_string();
            Ok(Some(token))
        }
        None => Ok(None),
    }
}

#[tauri::command]
pub async fn clear_stored_token(app: tauri::AppHandle) -> Result<(), String> {
    let store = app
        .store(STORE_PATH)
        .map_err(|e| format!("Failed to open store: {}", e))?;

    store.delete(TOKEN_KEY);

    store
        .save()
        .map_err(|e| format!("Failed to save store: {}", e))?;

    Ok(())
}

// Internal helper for getting token without command
pub async fn get_stored_token_internal(app: &tauri::AppHandle) -> Result<String, String> {
    let store = app
        .store(STORE_PATH)
        .map_err(|e| format!("Failed to open store: {}", e))?;

    match store.get(TOKEN_KEY) {
        Some(value) => {
            let token = value
                .as_str()
                .ok_or("Token is not a string")?
                .to_string();
            Ok(token)
        }
        None => Err("No token stored".to_string()),
    }
}
