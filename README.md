# Install sheets
Correr el comando en una terminal **powershell** en modo **administrador**.

El comando completo se usa de la siguiente manera, reemplazando <sheets-folder_name>, <your-github-username>, <your-github-token> (ghtoken debe tener scopes `repo` y `package:read`).
```sh
./install_sheets.ps1 -sheetsName <sheets-folder_name> -githubUsername <your-github-username> -ghToken <your-github-token>
```
## Argumentos
- **-sheetsName:** Carpeta donde se clonará el repo de sheets. Opcional con valor por defecto "sheets"
- **-githubUsername:** Nombre de usuario de github.
- **-ghToken:** Token de acceso a github. Se genera en https://github.com/settings/tokens y debe tener los scopes `repo` y `package:read`

-githubUsername y -ghToken son opcionales. Si no se especifican, el script instalará `gh` y hará login a github durante la instalación de sheets.
