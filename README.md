# Install sheets
Correr el comando en una terminal en modo administrador.

El comando completo se usa de la siguiente manera, reemplazando <sheets-folder_name>, <your-github-username>, <your-github-token> (ghtoken debe tener scopes `repo` y `package:read`).
```sh
Invoke-Expression "& { $(Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/CoderhubSpA/install/main/install_sheets.ps1') } -sheetsName <sheets-folder_name> -githubUsername <your-github-username> -ghToken <your-github-token>"
```
Alternativamente, se puede hacer que utilize la herramienta gh cli (para no tener que generar el token manualmente), y para eso se llama simplemente con:
```sh
Invoke-Expression "& { $(Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/CoderhubSpA/install/main/install_sheets.ps1') } -sheetsName <sheets-folder_name>"
```

Por default, el comando instala sheets en la carpeta sheets, usando:
```sh
Invoke-Expression "& { $(Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/CoderhubSpA/install/main/install_sheets.ps1') }"
```
