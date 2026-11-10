# Cloudflare Tunnel SSH naar TrueNAS (geverifieerd 2026-09-14)

Doel: vanaf een laptop **zonder adminrechten** via native `ssh.exe` op TrueNAS
kunnen inloggen, met bedrijfs-VPN actief — en tegelijk per agent/container een
eigen SSH-identiteit.

## Architectuur

```text
Werklaptop  ssh.exe + portable cloudflared.exe (ProxyCommand)
   -> example.com
   -> Cloudflare Access (IdP-login)
   -> bestaande Cloudflare Tunnel (zelfde tunnel als de web-apps)
   -> cloudflared-container op TrueNAS
   -> 192.0.2.10:22

Hermes  -> eigen key -> agent-hermes@192.0.2.10   (NIET via Cloudflare)
Archon  -> eigen key -> agent-archon@192.0.2.10   (NIET via Cloudflare)
```

## Harde regels (waarom)

- **Client-side `cloudflared` is verplicht.** Een gewone Cloudflare Tunnel
  publiceert geen publieke TCP-poort 22. Zonder ProxyCommand geeft
  `ssh user@ssh.domein` altijd `Connection timed out`, ook met een geldige key.
  De server-side `cloudflared` vervangt de client-side NIET.
- **Publiceer de tunnelroute met een leeg Path-veld.** Een pad zoals `^/blog`
  hoort bij HTTP-routes en breekt de SSH-route.
- **Gebruik een aparte hostname (`ssh.`), niet de webinterface-hostname.**
  `truenas.domein` is aan HTTP(S) gekoppeld en kan geen SSH vervoeren.
- **Cloudflare Access alleen is niet genoeg.** Het is de eerste laag; de
  TrueNAS SSH-key blijft de tweede laag.
- **RemoteCommand breekt `scp`/`sftp`.** Gebruik `scp -o RemoteCommand=none`.

## Windows-client zonder adminrechten

Portable executable, geen installatie/service/registry/PATH:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\Tools"
Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile "$env:USERPROFILE\Tools\cloudflared.exe"
Unblock-File "$env:USERPROFILE\Tools\cloudflared.exe"
```

`C:\Users\<user>\.ssh\config` (forward slashes):

```sshconfig
Host truenas
    HostName example.com
    User admin
    IdentityFile C:/Users/<user>/.ssh/truenas_private_key_rsa.txt
    IdentitiesOnly yes
    ProxyCommand C:/Users/<user>/Tools/cloudflared.exe access ssh --hostname %h
```

Een alias die direct in een container landt:

```sshconfig
Host hermes
    HostName example.com
    User admin
    IdentityFile C:/Users/<user>/.ssh/truenas_private_key_rsa.txt
    IdentitiesOnly yes
    ProxyCommand C:/Users/<user>/Tools/cloudflared.exe access ssh --hostname %h
    RequestTTY yes
    RemoteCommand sudo /mnt/HomeNAS/admin-tools/bin/app-shell hermes
```

`RequestTTY yes` is verplicht: zonder TTY faalt `sudo` met "a terminal is
required" en `docker exec -it` werkt niet.

## Foutdiagnose (echt gezien in deze sessie)

| Symptoom | Oorzaak | Oplossing |
|---|---|---|
| `Connection timed out` | Gewone `ssh` zonder ProxyCommand | ProxyCommand toevoegen |
| `CreateProcessW failed error:2` / `posix_spawnp: No such file or directory` | Programma in ProxyCommand bestaat niet op dat pad | `Test-Path` op het pad; juiste bestandsnaam/exe |
| Route matcht niet | Padveld gevuld (`^/blog`) | Path leegmaken |
| Werkt zonder VPN, niet met VPN | VPN blokkeert DNS/WebSocket/portable exe | IT laten toestaan; test `Test-NetConnection <host> -Port 443` |

Cloudflare Access vraagt standaard een **e-mailcode (One-time PIN)**. Dat is
niet om te zetten naar Google Authenticator. Wel mogelijk:
- **Cloudflare als IdP** (`restrict_to_account_members`) -> login met het
  Cloudflare-account, dat zelf al TOTP gebruikt. Dit vervangt de e-mailcode.
- **Independent MFA -> Authenticator application (TOTP)** in Access settings,
  enroll via `https://<team>.cloudflareaccess.com/AddMfaDevice`. Dit is een
  extra factor naast de IdP-login, geen vervanging.
- **Session Duration** op de Access-app + MFA Authentication duration verhogen
  bepaalt hoe vaak je opnieuw wordt gevraagd.

## Sudo-opties in TrueNAS SCALE

`Credentials > Users > <user> > Edit` -> **SSH Access** moet aanstaan, anders
worden de sudo-velden niet getoond -> **Sudo Command / Authorization**:

- `Allow all sudo commands` — wachtwoord 1x per sessie
- `Allow all sudo commands with no password` — nooit een prompt
- `Allowed sudo commands [with no password]` — alleen absolute paden

Ook instelbaar op de primaire groep: `Credentials > Groups > Edit`.

Advies: laat het wachtwoord staan waar het kan. Zonder sudo-wachtwoord is een
laptop met een geldige Access-sessie voldoende om root op TrueNAS te worden.

Test of sudo een wachtwoord vraagt:

```bash
ssh truenas 'sudo -n true && echo NOPASSWD || echo WACHTWOORD_NODIG'
```

## Wrapper i.p.v. onbeperkte sudo

Script staat op `/opt/data/scripts/truenas-setup-app-shell.sh` = host
`/mnt/HomeNAS/appdata/hermes/scripts/truenas-setup-app-shell.sh`. Draai het op
de host als:

```bash
sudo bash /mnt/HomeNAS/appdata/hermes/scripts/truenas-setup-app-shell.sh admin
```

Maakt `/mnt/HomeNAS/admin-tools/bin/app-shell` (root-owned, 755) met een
whitelist van containernamen. Optioneel zet het
`/etc/sudoers.d/app-shell` met NOPASSWD voor alleen dat script, gevalideerd met
`visudo -cf` vóór installatie.

Waarom een whitelist en niet `sudo docker`: `sudo docker ...` is gelijk aan
root. Geef nooit passwordless sudo op `docker`, `bash`, `sh`, `python`, `tee`,
`chmod`, `chown`, `mount` of een editor.

## Agent-keys (per container een eigen identiteit)

- Privésleutel in de container mounten via een host-path, read-only:
  `/mnt/HomeNAS/appdata/<app>/home/.ssh/id_ed25519`.
- `known_hosts` vooraf vullen met `ssh-keyscan -H 192.0.2.10` en de
  fingerprint controleren tegen `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.
- Per agent een eigen TrueNAS-gebruiker met een eigen publieke key.
- Archon draait als `user: "568:568"` -> `chown 568:568` op de key, mode 600.
- De container-UID opvragen met `sudo docker exec <naam> id` en daarop chownen.
