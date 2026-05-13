import json
import os
import urllib.request

def sanitize_filename(name):
    return "".join([c if c.isalnum() or c in " -_" else "_" for c in name]).strip()

def main():
    json_path = r"C:/Users/rtm473/.gemini/antigravity/brain/b9be85ec-f815-4bce-b8bd-f8ff02ac2477/.system_generated/steps/50/output.txt"
    output_dir = r"d:/dentalcare/stitch_screens"
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    screens = data.get("screens", [])
    print(f"Trovate {len(screens)} schermate nel JSON.")
    
    downloaded = 0
    for screen in screens:
        title = screen.get("title", "Untitled")
        screenshot = screen.get("screenshot", {})
        download_url = screenshot.get("downloadUrl")
        
        if download_url:
            # Crea un nome file sicuro
            filename = sanitize_filename(title) + ".png"
            filepath = os.path.join(output_dir, filename)
            
            # Gestione duplicati
            counter = 1
            original_filepath = filepath
            while os.path.exists(filepath):
                filepath = os.path.join(output_dir, f"{sanitize_filename(title)}_{counter}.png")
                counter += 1
                
            print(f"Scaricando: {title} -> {os.path.basename(filepath)}")
            try:
                urllib.request.urlretrieve(download_url, filepath)
                downloaded += 1
            except Exception as e:
                print(f"Errore durante il download di {title}: {e}")
        else:
            print(f"Nessun URL di download per: {title}")
            
    print(f"Download completato. Scaricate {downloaded} immagini in {output_dir}")

if __name__ == "__main__":
    main()
