#!/usr/bin/env python3
"""Ruota la password delle utenze demo.

La password demo e' committata in chiaro nel repo pubblico e nella storia git
(proposta #23): toglierla dai file non la rende segreta, perche' la storia e'
gia' clonata. L'unica misura efficace e' cambiarla.

Aggiorna SOLO il database. La configurazione del server va allineata a mano
subito dopo, altrimenti n8n smette di autenticarsi: lo script stampa i comandi.

Uso:
    python rotate_demo_password.py --db dentalcare_prod                 # dry-run
    python rotate_demo_password.py --db dentalcare_prod --apply
    python rotate_demo_password.py --db dentalcare_prod --apply --password 'Scelta1!'

Default: dry-run. Senza --apply non scrive nulla.
"""

import argparse
import secrets
import string
import sys

import bcrypt
import psycopg2

BCRYPT_COST = 10  # allineato agli hash esistenti ($2b$10$)
DEMO_DOMAIN = "@demo.dentalcare.it"


def generate_password(length: int = 20) -> str:
    """Password casuale senza caratteri ambigui, con almeno un simbolo."""
    alphabet = string.ascii_letters + string.digits + "!@#%*-_"
    while True:
        pwd = "".join(secrets.choice(alphabet) for _ in range(length))
        if (any(c.islower() for c in pwd) and any(c.isupper() for c in pwd)
                and any(c.isdigit() for c in pwd)
                and any(c in "!@#%*-_" for c in pwd)):
            return pwd


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="192.168.0.173")
    ap.add_argument("--db", required=True, help="dentalcare_prod | dentalcarepro")
    ap.add_argument("--user", default="postgres")
    ap.add_argument("--schema", default="t_9d754153", help="schema del tenant demo")
    ap.add_argument("--password", help="password da impostare (default: generata)")
    ap.add_argument("--apply", action="store_true", help="senza questo flag non scrive")
    args = ap.parse_args()

    import os
    pgpass = os.environ.get("PGPASSWORD")
    if not pgpass:
        print("ERRORE: esporta PGPASSWORD prima di lanciare.", file=sys.stderr)
        return 1

    new_password = args.password or generate_password()
    hashed = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt(BCRYPT_COST)).decode()

    conn = psycopg2.connect(host=args.host, dbname=args.db, user=args.user, password=pgpass)
    conn.autocommit = False
    cur = conn.cursor()

    cur.execute(
        f"SELECT email, role::text FROM {args.schema}.providers "
        "WHERE email LIKE %s ORDER BY email",
        (f"%{DEMO_DOMAIN}",),
    )
    accounts = cur.fetchall()
    if not accounts:
        print(f"Nessuna utenza {DEMO_DOMAIN} in {args.db}/{args.schema}: niente da fare.")
        return 1

    print(f"DB {args.db} | schema {args.schema} | {len(accounts)} utenze:")
    for email, role in accounts:
        print(f"  {email:38} {role}")

    if not args.apply:
        print("\nDRY-RUN: nessuna modifica. Rilancia con --apply per applicare.")
        return 0

    cur.execute(
        f"UPDATE {args.schema}.providers SET password_hash = %s, password_temporary = false "
        "WHERE email LIKE %s",
        (hashed, f"%{DEMO_DOMAIN}"),
    )
    updated = cur.rowcount
    conn.commit()
    cur.close()
    conn.close()

    print(f"\nAggiornate {updated} utenze.")
    print(f"\nNUOVA PASSWORD: {new_password}")
    print("Annotala ora: non e' recuperabile dall'hash.\n")
    print("Allinea SUBITO la config del server, o n8n smette di autenticarsi:")
    print("  ssh fpapale@192.168.0.72")
    print("  cd ~/docker/dentalcarepro")
    print("  # in config/application-prod.properties, aggiorna:")
    print(f"  #   app.demo.password={new_password}")
    print(f"  #   app.n8n.admin-password={new_password}   (se presente)")
    print("  docker compose restart backend")
    print("\nNON committare la nuova password: e' esattamente l'errore da cui veniamo.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
