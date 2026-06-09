import json, os, uuid, sys

def uid(): return str(uuid.uuid4())

DENTALCARE_API = 'http://localhost:8080/api'

def auth_header(login_node):
    return {"name": "Authorization",
            "value": f"=Bearer {{{{ $('{login_node}').first().json.token }}}}"}

SERVICE_KEY_PLACEHOLDER = 'REPLACE_WITH_SECRET'

def make_service_key_node(name, pos):
    """Set node — user changes SERVICE_KEY_PLACEHOLDER with the actual secret once."""
    return {
        "id": uid(), "name": name, "type": "n8n-nodes-base.set",
        "typeVersion": 3.4, "position": pos,
        "parameters": {
            "mode": "manual",
            "assignments": {
                "assignments": [
                    {
                        "id": uid(),
                        "name": "serviceKey",
                        "value": SERVICE_KEY_PLACEHOLDER,
                        "type": "string"
                    }
                ]
            },
            "options": {}
        }
    }

def make_login_node(name, service_key_node_name, pos):
    return {
        "id": uid(), "name": name, "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2, "position": pos,
        "parameters": {
            "method": "POST",
            "url": f"{DENTALCARE_API}/public/service-token",
            "sendHeaders": True,
            "headerParameters": {
                "parameters": [
                    {
                        "name": "X-N8N-Key",
                        "value": f"={{{{ $('{service_key_node_name}').first().json.serviceKey }}}}"
                    }
                ]
            },
            "options": {}
        }
    }

def http_tool(name, method, url_suffix, query_params, body_params, pos, login_node_name, dynamic_url=None):
    url = dynamic_url if dynamic_url else f"{DENTALCARE_API}{url_suffix}"
    params = {
        "method": method,
        "url": url,
        "sendHeaders": True,
        "headerParameters": {"parameters": [auth_header(login_node_name)]},
        "options": {}
    }
    if query_params:
        params["sendQuery"] = True
        params["queryParameters"] = {"parameters": query_params}
    if body_params:
        params["sendBody"] = True
        params["contentType"] = "json"
        params["bodyParameters"] = {"parameters": body_params}
    return {
        "id": uid(), "name": name, "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2, "position": pos, "parameters": params
    }

# load original
with open(os.environ['TEMP'] + '/workflow_original.json') as f:
    orig = json.load(f)

def orig_node(name):
    for n in orig['nodes']:
        if n['name'] == name:
            return json.loads(json.dumps(n))
    raise KeyError(name)

def orig_copy(name, pos):
    n = orig_node(name)
    n['id'] = uid()
    n['position'] = pos
    return n

WH0 = uid(); WH1 = uid(); WH2 = uid()

# ── SECTION 1: CHECK AVAILABILITY ────────────────────────────────────────────
wh0_orig = orig_node('Webhook')
n_wh0 = {**wh0_orig, 'id': uid(), 'position': [100, 300],
          'parameters': {**wh0_orig['parameters'], 'path': WH0},
          'webhookId': WH0}
n_svckey0 = make_service_key_node('Service Key', [280, 300])
n_login0  = make_login_node('Login DentalCare', 'Service Key', [460, 300])
n_oai0    = orig_copy('OpenAI Chat Model', [640, 520])
n_resp0   = orig_copy('Respond to Webhook', [1100, 300])
n_check   = http_tool(
    'Controlla appuntamenti DentalCare', 'GET', '/appointments',
    [
        {"name": "from", "value": "={{ $fromAI('Start_Time', 'Inizio intervallo ISO 8601 con fuso orario', 'string') }}"},
        {"name": "to",   "value": "={{ $fromAI('End_Time',   'Fine intervallo ISO 8601 con fuso orario',   'string') }}"}
    ], None, [640, 380], 'Login DentalCare')
n_agent0 = {
    "id": uid(), "name": "AI Agent", "type": "@n8n/n8n-nodes-langchain.agent",
    "typeVersion": 1.7, "position": [750, 300],
    "parameters": {
        "promptType": "define",
        "text": "=## Ruolo\n\nSei un verificatore di disponibilita' appuntamenti dello Studio Dentistico DentalCare.\nUsa il gestionale DentalCare per controllare gli appuntamenti esistenti.\n\n**Data e ora attuali:** {{ $now }}\n**Orario richiesto:** {{ $json.body.args.time }}\n\n## Processo\n1. Usa **Controlla appuntamenti DentalCare** per vedere gli appuntamenti nella finestra oraria richiesta (from=inizio slot, to=fine slot 1 ora dopo).\n2. Se lo slot e' libero (nessun appuntamento restituito o appuntamenti non sovrapposti), confermalo.\n3. Se occupato, suggerisci fino a 3 slot alternativi vicini, verificando la disponibilita'.\n4. Orario lavorativo: 08:00-20:00, no sabato/domenica.\n\n## Note\n- Non proporre mai orari nel passato.\n- Tono naturale e conversazionale in italiano.",
        "options": {}
    }
}

# ── SECTION 2: BOOK APPOINTMENT ───────────────────────────────────────────────
wh1_orig = orig_node('Webhook1')
n_wh1 = {**wh1_orig, 'id': uid(), 'position': [100, 1000],
          'parameters': {**wh1_orig['parameters'], 'path': WH1},
          'webhookId': WH1}
n_svckey1   = make_service_key_node('Service Key 1', [280, 1000])
n_login1    = make_login_node('Login DentalCare 1', 'Service Key 1', [460, 1000])
n_oai1      = orig_copy('OpenAI Chat Model1', [340, 1500])
n_resp1     = orig_copy('Respond to Webhook1', [1400, 1000])
n_gmail1    = orig_copy('Send a message in Gmail', [340, 1380])
n_search_pt = http_tool('Cerca paziente DentalCare', 'GET', '/patients',
    [{"name": "search", "value": "={{ $fromAI('patient_search', 'Telefono o email del paziente da cercare', 'string') }}"}],
    None, [700, 1200], 'Login DentalCare 1')
n_create_pt = http_tool('Crea paziente DentalCare', 'POST', '/patients', None,
    [
        {"name": "firstName", "value": "={{ $fromAI('firstName', 'Nome del paziente', 'string') }}"},
        {"name": "lastName",  "value": "={{ $fromAI('lastName',  'Cognome del paziente', 'string') }}"},
        {"name": "phone",     "value": "={{ $fromAI('phone',     'Numero di telefono', 'string') }}"},
        {"name": "email",     "value": "={{ $fromAI('email',     'Indirizzo email', 'string') }}"}
    ], [900, 1200], 'Login DentalCare 1')
n_providers = http_tool('Lista medici DentalCare', 'GET', '/providers',
    [{"name": "activeOnly", "value": "true"}], None, [1100, 1200], 'Login DentalCare 1')
n_chairs    = http_tool('Lista poltrone DentalCare', 'GET', '/appointments/chairs',
    None, None, [1300, 1200], 'Login DentalCare 1')
n_book      = http_tool('Prenota appuntamento DentalCare', 'POST', '/appointments', None,
    [
        {"name": "patientId",  "value": "={{ $fromAI('patientId',  'UUID del paziente',              'string') }}"},
        {"name": "providerId", "value": "={{ $fromAI('providerId', 'UUID del medico',                'string') }}"},
        {"name": "chairLabel", "value": "={{ $fromAI('chairLabel', 'Etichetta poltrona o sala',       'string') }}"},
        {"name": "startsAt",   "value": "={{ $fromAI('startsAt',   'Orario inizio ISO 8601',          'string') }}"},
        {"name": "endsAt",     "value": "={{ $fromAI('endsAt',     'Orario fine ISO 8601',            'string') }}"},
        {"name": "notes",      "value": "={{ $fromAI('notes',      'Note o tipo di servizio',         'string') }}"}
    ], [1100, 1000], 'Login DentalCare 1')
n_agent1 = {
    "id": uid(), "name": "AI Agent1", "type": "@n8n/n8n-nodes-langchain.agent",
    "typeVersion": 1.7, "position": [750, 1000],
    "parameters": {
        "promptType": "define",
        "text": "=## Ruolo\n\nSei un agente AI per la prenotazione appuntamenti dello Studio Dentistico DentalCare.\n\n**Data e ora attuali:** {{ $now }}\n**Paziente:** {{ $json.body.args.name }}\n**Email:** {{ $json.body.args.email }}\n**Telefono:** {{ $json.body.args.phone }}\n**Servizio:** {{ $json.body.args.service_type }}\n**Orario:** {{ $json.body.args.time }}\n\n## Processo step-by-step\n1. **Cerca paziente DentalCare** con telefono o email. Se trovato, usa il patientId restituito.\n2. Se non trovato, usa **Crea paziente DentalCare**: splitta il nome completo in firstName e lastName.\n3. **Lista medici DentalCare**: scegli il providerId piu' adatto al servizio richiesto (dentista per cure, igienista per pulizia, ecc.).\n4. **Lista poltrone DentalCare**: scegli la prima chairLabel disponibile.\n5. **Prenota appuntamento DentalCare**: patientId, providerId, chairLabel, startsAt=orario richiesto, endsAt=+1h, notes=service_type.\n6. Se prenotazione ok, usa **Send a message in Gmail** per inviare conferma email al paziente.\n\n## Regole\n- endsAt = startsAt + 1 ora esatta.\n- Non inventare UUIDs: usa solo quelli restituiti dalle API.\n- Se prenotazione fallisce per conflitto, comunicalo e suggerisci orario alternativo.",
        "options": {}
    }
}

# ── SECTION 3: MODIFY APPOINTMENT ────────────────────────────────────────────
wh2_orig = orig_node('Webhook2')
n_wh2 = {**wh2_orig, 'id': uid(), 'position': [100, 1800],
          'parameters': {**wh2_orig['parameters'], 'path': WH2},
          'webhookId': WH2}
n_svckey2   = make_service_key_node('Service Key 2', [280, 1800])
n_login2    = make_login_node('Login DentalCare 2', 'Service Key 2', [460, 1800])
n_oai2      = orig_copy('OpenAI Chat Model2', [340, 2200])
n_resp2     = orig_copy('Respond to Webhook2', [1400, 1800])
n_gmail2    = orig_copy('Send an updated confirmation in Gmail', [340, 2080])
n_find_appt = http_tool('Cerca appuntamento da spostare', 'GET', '/appointments',
    [
        {"name": "from", "value": "={{ $fromAI('Search_After',  'Inizio finestra di ricerca ISO 8601', 'string') }}"},
        {"name": "to",   "value": "={{ $fromAI('Search_Before', 'Fine finestra di ricerca ISO 8601',   'string') }}"}
    ], None, [700, 2000], 'Login DentalCare 2')
n_reschedule = http_tool(
    'Sposta appuntamento DentalCare', 'PATCH', None, None,
    [
        {"name": "startsAt",   "value": "={{ $fromAI('New_Start',   'Nuovo orario inizio ISO 8601',   'string') }}"},
        {"name": "endsAt",     "value": "={{ $fromAI('New_End',     'Nuovo orario fine ISO 8601',     'string') }}"},
        {"name": "chairLabel", "value": "={{ $fromAI('Chair_Label', 'Etichetta poltrona originale',   'string') }}"}
    ], [900, 2000], 'Login DentalCare 2',
    dynamic_url=f"{DENTALCARE_API}/appointments/={{{{ $fromAI('Appointment_ID', 'UUID appuntamento da spostare', 'string') }}}}/reschedule"
)
n_agent2 = {
    "id": uid(), "name": "AI Agent2", "type": "@n8n/n8n-nodes-langchain.agent",
    "typeVersion": 1.7, "position": [750, 1800],
    "parameters": {
        "promptType": "define",
        "text": "=## Ruolo\n\nSei un agente AI per la modifica appuntamenti dello Studio Dentistico DentalCare.\n\n**Data e ora attuali:** {{ $now }}\n**Paziente:** {{ $json.body.args.name }}\n**Email:** {{ $json.body.args.email }}\n**Telefono:** {{ $json.body.args.phone }}\n**Appuntamento attuale da spostare:** {{ $json.body.args.current_time }}\n**Nuovo orario richiesto:** {{ $json.body.args.new_time }}\n\n## Processo\n1. **Cerca appuntamento da spostare**: usa finestra centrata su current_time (es. current_time - 2h / current_time + 2h).\n2. Filtra i risultati: cerca l'appuntamento che corrisponde a nome/email/telefono del paziente e orario attuale.\n3. Se trovi un unico match chiaro, prendi il suo appointmentId e la chairLabel originale.\n4. **Sposta appuntamento DentalCare**: usa appointmentId, new_start=new_time, new_end=new_time+1h, chair_label=originale.\n5. Dopo spostamento ok, usa **Send an updated confirmation in Gmail**.\n\n## Regole\n- Non spostare mai l'appuntamento sbagliato.\n- Se ambiguita' o nessun match: non aggiornare, rispondi che serve verifica manuale.\n- endsAt = new_start + 1 ora.",
        "options": {}
    }
}

# ── SECTION 4: CANCEL APPOINTMENT ────────────────────────────────────────────
WH3 = uid()
wh3_orig = orig_node('Webhook2')   # reuse structure, override path/id
n_wh3 = {**wh3_orig, 'id': uid(), 'name': 'Webhook3', 'position': [100, 2600],
          'parameters': {**wh3_orig['parameters'], 'path': WH3},
          'webhookId': WH3}
n_svckey3   = make_service_key_node('Service Key 3', [280, 2600])
n_login3    = make_login_node('Login DentalCare 3', 'Service Key 3', [460, 2600])
n_oai3      = orig_copy('OpenAI Chat Model2', [340, 3000])
n_oai3['name'] = 'OpenAI Chat Model3'
n_resp3     = orig_copy('Respond to Webhook2', [1200, 2600])
n_resp3['name'] = 'Respond to Webhook3'

n_find_cancel = http_tool('Cerca appuntamento da cancellare', 'GET', '/appointments',
    [
        {"name": "from", "value": "={{ $fromAI('Search_After',  'Inizio finestra di ricerca ISO 8601', 'string') }}"},
        {"name": "to",   "value": "={{ $fromAI('Search_Before', 'Fine finestra di ricerca ISO 8601',   'string') }}"}
    ], None, [700, 2800], 'Login DentalCare 3')

n_cancel = http_tool(
    'Cancella appuntamento DentalCare', 'PATCH', None, None, None,
    [900, 2800], 'Login DentalCare 3',
    dynamic_url=f"{DENTALCARE_API}/appointments/={{{{ $fromAI('Appointment_ID', 'UUID appuntamento da cancellare', 'string') }}}}/status?status=cancelled"
)

# Gmail cancellation confirmation — clone from gmail2 and rename
n_gmail3 = orig_copy('Send an updated confirmation in Gmail', [340, 2880])
n_gmail3['name'] = 'Send cancellation confirmation in Gmail'
n_gmail3['parameters'] = {
    "sendTo":    "={{ $json.body.args.email }}",
    "subject":   "=Cancellazione appuntamento DentalCare per {{ $json.body.args.name }}",
    "emailType": "text",
    "message":   "=Ciao {{ $json.body.args.name }}!\n\nTi confermiamo che il tuo appuntamento presso Studio Dentistico DentalCare del {{ $json.body.args.appointment_time }} per {{ $json.body.args.service_type }} è stato cancellato.\n\nSe hai bisogno di riprenotare, non esitare a contattarci.\n\nA presto!\n\nStudio Dentistico DentalCare",
    "options": {}
}

n_agent3 = {
    "id": uid(), "name": "AI Agent3", "type": "@n8n/n8n-nodes-langchain.agent",
    "typeVersion": 1.7, "position": [750, 2600],
    "parameters": {
        "promptType": "define",
        "text": "=## Ruolo\n\nSei un agente AI per la cancellazione appuntamenti dello Studio Dentistico DentalCare.\n\n**Data e ora attuali:** {{ $now }}\n**Paziente:** {{ $json.body.args.name }}\n**Email:** {{ $json.body.args.email }}\n**Telefono:** {{ $json.body.args.phone }}\n**Appuntamento da cancellare:** {{ $json.body.args.appointment_time }}\n**Servizio:** {{ $json.body.args.service_type }}\n\n## Processo\n1. **Cerca appuntamento da cancellare**: usa finestra centrata su appointment_time (es. appointment_time - 2h / appointment_time + 2h).\n2. Filtra risultati per nome/email/telefono paziente e orario. Trova un unico match certo.\n3. Se match trovato, usa **Cancella appuntamento DentalCare** con l'appointmentId trovato.\n4. Dopo cancellazione ok, usa **Send cancellation confirmation in Gmail**.\n\n## Regole\n- Non cancellare mai l'appuntamento sbagliato.\n- Se ambiguita' o nessun match: non procedere, rispondi che serve verifica manuale.\n- La cancellazione imposta status=cancelled: azione irreversibile, verifica prima di procedere.",
        "options": {}
    }
}

# sticky notes
n_sticky0 = {"id": uid(), "name": "Sticky Note", "type": "n8n-nodes-base.stickyNote",
              "typeVersion": 1, "position": [60, 220],
              "parameters": {"color": 4, "content": "## 1. CHECK AVAILABILITY\nDentalCare REST API\n/api/appointments"}}
n_sticky1 = {"id": uid(), "name": "Sticky Note1", "type": "n8n-nodes-base.stickyNote",
              "typeVersion": 1, "position": [60, 920],
              "parameters": {"color": 5, "content": "## 2. BOOK APPOINTMENT\nDentalCare REST API\n/api/patients + /api/appointments"}}
n_sticky2 = {"id": uid(), "name": "Sticky Note2", "type": "n8n-nodes-base.stickyNote",
              "typeVersion": 1, "position": [60, 1720],
              "parameters": {"color": 6, "content": "## 3. MODIFY APPOINTMENT\nDentalCare REST API\n/api/appointments/{id}/reschedule"}}
n_sticky3 = {"id": uid(), "name": "Sticky Note3", "type": "n8n-nodes-base.stickyNote",
              "typeVersion": 1, "position": [60, 2520],
              "parameters": {"color": 3, "content": "## 4. CANCEL APPOINTMENT\nDentalCare REST API\n/api/appointments/{id}/status?status=cancelled"}}

nodes = [
    n_sticky0, n_wh0, n_svckey0, n_login0, n_agent0, n_oai0, n_check, n_resp0,
    n_sticky1, n_wh1, n_svckey1, n_login1, n_agent1, n_oai1,
    n_search_pt, n_create_pt, n_providers, n_chairs, n_book, n_gmail1, n_resp1,
    n_sticky2, n_wh2, n_svckey2, n_login2, n_agent2, n_oai2,
    n_find_appt, n_reschedule, n_gmail2, n_resp2,
    n_sticky3, n_wh3, n_svckey3, n_login3, n_agent3, n_oai3,
    n_find_cancel, n_cancel, n_gmail3, n_resp3
]

connections = {}
def conn(src, src_port, dst, dst_port='main'):
    if src not in connections:
        connections[src] = {}
    if src_port not in connections[src]:
        connections[src][src_port] = [[]]
    connections[src][src_port][0].append({"node": dst, "type": dst_port, "index": 0})

# section 1
conn('Webhook',          'main',             'Service Key')
conn('Service Key',      'main',             'Login DentalCare')
conn('Login DentalCare', 'main',             'AI Agent')
conn('OpenAI Chat Model','ai_languageModel', 'AI Agent', 'ai_languageModel')
conn('Controlla appuntamenti DentalCare','ai_tool','AI Agent','ai_tool')
conn('AI Agent',         'main',             'Respond to Webhook')
# section 2
conn('Webhook1',           'main',             'Service Key 1')
conn('Service Key 1',      'main',             'Login DentalCare 1')
conn('Login DentalCare 1', 'main',             'AI Agent1')
conn('OpenAI Chat Model1', 'ai_languageModel', 'AI Agent1', 'ai_languageModel')
conn('Cerca paziente DentalCare',           'ai_tool','AI Agent1','ai_tool')
conn('Crea paziente DentalCare',            'ai_tool','AI Agent1','ai_tool')
conn('Lista medici DentalCare',             'ai_tool','AI Agent1','ai_tool')
conn('Lista poltrone DentalCare',           'ai_tool','AI Agent1','ai_tool')
conn('Prenota appuntamento DentalCare',     'ai_tool','AI Agent1','ai_tool')
conn('Send a message in Gmail',             'ai_tool','AI Agent1','ai_tool')
conn('AI Agent1',          'main',             'Respond to Webhook1')
# section 3
conn('Webhook2',           'main',             'Service Key 2')
conn('Service Key 2',      'main',             'Login DentalCare 2')
conn('Login DentalCare 2', 'main',             'AI Agent2')
conn('OpenAI Chat Model2', 'ai_languageModel', 'AI Agent2', 'ai_languageModel')
conn('Cerca appuntamento da spostare',      'ai_tool','AI Agent2','ai_tool')
conn('Sposta appuntamento DentalCare',      'ai_tool','AI Agent2','ai_tool')
conn('Send an updated confirmation in Gmail','ai_tool','AI Agent2','ai_tool')
conn('AI Agent2',          'main',             'Respond to Webhook2')
# section 4
conn('Webhook3',           'main',             'Service Key 3')
conn('Service Key 3',      'main',             'Login DentalCare 3')
conn('Login DentalCare 3', 'main',             'AI Agent3')
conn('OpenAI Chat Model3', 'ai_languageModel', 'AI Agent3', 'ai_languageModel')
conn('Cerca appuntamento da cancellare',    'ai_tool','AI Agent3','ai_tool')
conn('Cancella appuntamento DentalCare',    'ai_tool','AI Agent3','ai_tool')
conn('Send cancellation confirmation in Gmail','ai_tool','AI Agent3','ai_tool')
conn('AI Agent3',          'main',             'Respond to Webhook3')

new_wf = {
    "name": "SegretarIA DentalCare Pro",
    "nodes": nodes,
    "connections": connections,
    "settings": orig.get('settings', {"executionOrder": "v1"}),
    "staticData": None
}

out = os.environ['TEMP'] + '/workflow_new.json'
with open(out, 'w', encoding='utf-8') as f:
    json.dump(new_wf, f, ensure_ascii=False, indent=2)

print("SAVED:", out)
print(f"WH0 check_availability : {WH0}")
print(f"WH1 book_appointment   : {WH1}")
print(f"WH2 modify_appointment : {WH2}")
