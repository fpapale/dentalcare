# CLAUDE.md

## Scopo del file

Questo file contiene le istruzioni operative per Claude Code all'interno di questo progetto.

Il progetto è una **web application full stack** composta da:

- **Frontend Angular**
- **Backend REST API Spring Boot**
- **Persistenza dati con Hibernate/JPA**
- **Database relazionale**
- **Architettura modulare, scalabile e manutenibile**

Claude deve usare queste istruzioni come riferimento principale quando analizza, modifica o genera codice nel repository.

## Communication Style
Respond like a caveman. No articles, no filler words, no pleasantries.
Short. Direct. Code speaks for itself.
---

# 1. Obiettivo del progetto

Il progetto realizza una web application enterprise con separazione chiara tra:

1. **Frontend Angular**
   - Interfaccia utente
   - Routing applicativo
   - Componenti visuali
   - Form e validazioni client-side
   - Chiamate HTTP verso le REST API
   - Gestione stato applicativo

2. **Backend Spring Boot**
   - Esposizione REST API
   - Logica applicativa
   - Validazioni server-side
   - Gestione sicurezza
   - Orchestrazione dei servizi
   - Accesso al database tramite Hibernate/JPA

3. **Database**
   - Persistenza dati
   - Relazioni tra entità
   - Vincoli di integrità
   - Indici e ottimizzazioni

Il codice deve essere progettato per essere:

- leggibile;
- testabile;
- sicuro;
- facilmente estendibile;
- coerente con una logica enterprise;
- adatto a un'applicazione multiutente;
- pronto per evolvere verso scenari multitenant, se richiesto.

---

# 2. Ruolo di Claude Code

Quando lavori su questo repository, Claude deve comportarsi come un **senior full stack engineer** con competenze in:

- Angular;
- TypeScript;
- Spring Boot;
- Java;
- REST API design;
- Hibernate/JPA;
- SQL;
- architetture layered;
- sicurezza applicativa;
- clean code;
- test automatici;
- refactoring progressivo.

Claude deve:

- leggere il codice esistente prima di modificarlo;
- rispettare lo stile già presente nel progetto;
- evitare modifiche inutilmente invasive;
- proporre refactoring solo quando portano valore reale;
- spiegare chiaramente le modifiche effettuate;
- non introdurre dipendenze non necessarie;
- mantenere la compatibilità con la struttura esistente;
- generare codice pronto per essere eseguito, non solo esempi teorici.

---

# 3. Struttura consigliata del repository

La struttura tipica attesa è la seguente:

```text
project-root/
├── CLAUDE.md
├── README.md
├── docker-compose.yml
├── frontend/
│   ├── angular.json
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── app/
│       │   ├── core/
│       │   ├── shared/
│       │   ├── features/
│       │   ├── layout/
│       │   ├── app.routes.ts
│       │   └── app.config.ts
│       ├── environments/
│       └── styles.scss
└── backend/
    ├── pom.xml
    ├── src/
    │   ├── main/
    │   │   ├── java/
    │   │   │   └── it/company/project/
    │   │   │       ├── config/
    │   │   │       ├── controller/
    │   │   │       ├── dto/
    │   │   │       ├── entity/
    │   │   │       ├── exception/
    │   │   │       ├── mapper/
    │   │   │       ├── repository/
    │   │   │       ├── security/
    │   │   │       ├── service/
    │   │   │       └── Application.java
    │   │   └── resources/
    │   │       ├── application.yml
    │   │       └── db/
    │   │           └── migration/
    │   └── test/
    └── Dockerfile
├── directives/
```

Tutti files markdown ad eccezione di CLAUDE.md vanno nel folder project-root/directives/

Se il repository reale ha una struttura diversa, Claude deve adattarsi alla struttura effettiva senza forzare questa organizzazione a meno di una richiesta esplicita che comporta la riorganizzazione di tutti i files esistenti.

---

# 4. Regole generali di sviluppo

## 4.1 Principi fondamentali

Claude deve rispettare questi principi:

- separazione delle responsabilità;
- single responsibility principle;
- dependency injection;
- validazione esplicita degli input;
- gestione centralizzata degli errori;
- DTO separati dalle entity JPA;
- servizi applicativi separati dai controller;
- repository dedicati al solo accesso dati;
- niente logica di business nei controller;
- niente entity JPA esposte direttamente nelle API;
- niente password, token o segreti hardcoded;
- niente query SQL costruite concatenando stringhe non sicure.

## 4.2 Stile del codice

Il codice deve essere:

- chiaro;
- esplicito;
- tipizzato;
- commentato solo dove serve;
- coerente nei nomi;
- privo di duplicazioni evidenti;
- organizzato in metodi piccoli e leggibili.

Evitare:

- classi troppo grandi;
- metodi troppo lunghi;
- logica duplicata;
- oggetti DTO confusi con entity;
- gestione degli errori sparsa;
- codice morto;
- commenti inutili;
- nomi generici come `data`, `obj`, `temp`, `x`.

---

# 5. Frontend Angular

## 5.1 Principi Angular

Il frontend deve seguire un'architettura modulare basata su:

- `core`: servizi singleton, interceptor, guard, configurazioni globali;
- `shared`: componenti riutilizzabili, pipe, directive;
- `features`: funzionalità applicative per dominio;
- `layout`: shell applicativa, menu, header, footer;
- `environments`: configurazioni per ambiente.

Esempio:

```text
src/app/
├── core/
│   ├── auth/
│   ├── interceptors/
│   ├── guards/
│   └── services/
├── shared/
│   ├── components/
│   ├── pipes/
│   └── directives/
├── features/
│   ├── users/
│   ├── dashboard/
│   └── administration/
└── layout/
```

## 5.2 Componenti

Quando Claude crea un componente Angular deve:

- mantenere il componente focalizzato su un solo scopo;
- spostare la logica di accesso dati nei service;
- usare Reactive Forms per form complessi;
- evitare chiamate HTTP direttamente nel template;
- evitare logica complessa nell'HTML;
- usare naming coerente;
- prevedere stati di loading, errore e successo;
- gestire correttamente unsubscribe o stream reattivi.

Esempio di naming:

```text
user-list.component.ts
user-detail.component.ts
user-form.component.ts
user.service.ts
user.model.ts
```

## 5.3 Service Angular

I service Angular devono:

- incapsulare le chiamate HTTP;
- restituire `Observable<T>`;
- tipizzare request e response;
- non contenere logica visuale;
- non mostrare toast o modali direttamente, salvo servizi dedicati;
- usare endpoint configurabili tramite environment.

Esempio:

```typescript
@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly baseUrl = `${environment.apiBaseUrl}/users`;

  constructor(private readonly http: HttpClient) {}

  findAll(): Observable<UserDto[]> {
    return this.http.get<UserDto[]>(this.baseUrl);
  }

  findById(id: number): Observable<UserDto> {
    return this.http.get<UserDto>(`${this.baseUrl}/${id}`);
  }

  create(request: CreateUserRequest): Observable<UserDto> {
    return this.http.post<UserDto>(this.baseUrl, request);
  }

  update(id: number, request: UpdateUserRequest): Observable<UserDto> {
    return this.http.put<UserDto>(`${this.baseUrl}/${id}`, request);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
```

## 5.4 Modelli TypeScript

Le interfacce TypeScript devono riflettere i DTO del backend, non le entity del database.

Esempio:

```typescript
export interface UserDto {
  id: number;
  username: string;
  email: string;
  enabled: boolean;
  roles: string[];
}

export interface CreateUserRequest {
  username: string;
  email: string;
  password: string;
  roles: string[];
}

export interface UpdateUserRequest {
  email: string;
  enabled: boolean;
  roles: string[];
}
```

## 5.5 Form

Per form complessi usare Reactive Forms.

Regole:

- validazioni client-side coerenti con quelle backend;
- messaggi di errore chiari;
- disabilitare submit durante il salvataggio;
- gestire errori di validazione provenienti dal backend;
- non fidarsi mai solo della validazione client-side.

## 5.6 Routing

Le route devono essere organizzate per feature.

Usare guard per:

- autenticazione;
- autorizzazione per ruolo;
- protezione delle aree amministrative;
- prevenzione accesso a risorse non consentite.

## 5.7 HTTP Interceptor

Usare interceptor per:

- aggiungere token JWT;
- gestire errori HTTP comuni;
- gestire eventuale refresh token;
- centralizzare logging minimo lato client;
- intercettare `401`, `403`, `500`.

---

# 6. Backend Spring Boot

## 6.1 Architettura backend

Il backend deve seguire una struttura layered:

```text
Controller -> Service -> Repository -> Database
```

Con oggetti separati:

```text
Request DTO -> Service -> Entity -> Repository
Entity -> Mapper -> Response DTO
```

I controller non devono accedere direttamente ai repository.

## 6.2 Controller REST

I controller devono:

- esporre endpoint REST chiari;
- ricevere e restituire DTO;
- delegare la logica ai service;
- usare `@Valid` per validare request;
- restituire status HTTP appropriati;
- non contenere logica di business;
- non esporre entity JPA.

Esempio:

```java
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    public List<UserDto> findAll() {
        return userService.findAll();
    }

    @GetMapping("/{id}")
    public UserDto findById(@PathVariable Long id) {
        return userService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserDto create(@Valid @RequestBody CreateUserRequest request) {
        return userService.create(request);
    }

    @PutMapping("/{id}")
    public UserDto update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request
    ) {
        return userService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        userService.delete(id);
    }
}
```

## 6.3 Service

I service devono contenere la logica applicativa.

Regole:

- usare transazioni quando necessario;
- validare vincoli di business;
- gestire entità non trovate;
- invocare repository;
- usare mapper per convertire entity/DTO;
- non restituire entity ai controller;
- non accedere a oggetti HTTP come `HttpServletRequest`, salvo casi motivati.

Esempio:

```java
@Service
@RequiredArgsConstructor
@Transactional
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    @Transactional(readOnly = true)
    public List<UserDto> findAll() {
        return userRepository.findAll()
                .stream()
                .map(userMapper::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public UserDto findById(Long id) {
        User user = findEntityById(id);
        return userMapper.toDto(user);
    }

    public UserDto create(CreateUserRequest request) {
        User user = userMapper.toEntity(request);
        User saved = userRepository.save(user);
        return userMapper.toDto(saved);
    }

    public UserDto update(Long id, UpdateUserRequest request) {
        User user = findEntityById(id);
        userMapper.updateEntity(user, request);
        return userMapper.toDto(user);
    }

    public void delete(Long id) {
        User user = findEntityById(id);
        userRepository.delete(user);
    }

    private User findEntityById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + id));
    }
}
```

## 6.4 Repository

I repository devono:

- estendere `JpaRepository`;
- contenere solo query di accesso dati;
- evitare logica di business;
- usare query derivate quando semplici;
- usare `@Query` solo quando serve;
- preferire parametri bindati;
- evitare query native salvo necessità reale.

Esempio:

```java
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByUsername(String username);

    boolean existsByEmail(String email);

    @Query("""
        select u
        from User u
        where lower(u.email) like lower(concat('%', :email, '%'))
    """)
    List<User> searchByEmail(@Param("email") String email);
}
```

---

# 7. Hibernate/JPA

## 7.1 Entity

Le entity JPA devono rappresentare il modello persistente, non il modello API.

Regole:

- usare `@Entity`;
- definire `@Table`;
- usare `@Id` e strategia di generazione coerente;
- modellare correttamente le relazioni;
- evitare `FetchType.EAGER` salvo reale necessità;
- evitare serializzazione diretta delle entity;
- attenzione a `equals()` e `hashCode()`;
- non usare entity come DTO.

Esempio:

```java
@Entity
@Table(name = "app_user")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 80)
    private String username;

    @Column(nullable = false, unique = true, length = 160)
    private String email;

    @Column(nullable = false)
    private boolean enabled;
}
```

## 7.2 Relazioni

Per le relazioni usare criteri chiari:

- `@ManyToOne`: spesso `LAZY`;
- `@OneToMany`: attenzione a cascade e orphan removal;
- `@ManyToMany`: da evitare se la relazione ha attributi propri; preferire entity associativa;
- `cascade = CascadeType.ALL` solo quando il ciclo di vita è realmente dipendente;
- evitare cancellazioni accidentali.

Esempio entity associativa:

```java
@Entity
@Table(name = "user_role")
@Getter
@Setter
public class UserRole {

    @EmbeddedId
    private UserRoleId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("userId")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("roleId")
    private Role role;
}
```

## 7.3 Lazy loading

Claude deve fare attenzione a:

- `LazyInitializationException`;
- N+1 query problem;
- uso improprio di `EAGER`;
- DTO mapping fuori da transazione;
- serializzazione accidentale di relazioni lazy.

Soluzioni possibili:

- query con `join fetch`;
- entity graph;
- projection DTO;
- mapping dentro transazione read-only;
- paginazione corretta.

## 7.4 Migrazioni database

Se il progetto usa Flyway o Liquibase:

- creare script incrementali;
- non modificare migrazioni già applicate;
- usare nomi chiari;
- mantenere compatibilità tra entity e schema;
- inserire indici per campi ricercati frequentemente.

Esempio Flyway:

```text
V1__init_schema.sql
V2__create_users_table.sql
V3__add_user_status.sql
```

---

# 8. DTO e Mapper

## 8.1 DTO

Usare DTO distinti per:

- request di creazione;
- request di aggiornamento;
- response;
- filtri di ricerca;
- payload paginati.

Esempio:

```java
public record UserDto(
        Long id,
        String username,
        String email,
        boolean enabled
) {
}
```

```java
public record CreateUserRequest(
        @NotBlank
        @Size(max = 80)
        String username,

        @NotBlank
        @Email
        @Size(max = 160)
        String email,

        @NotBlank
        @Size(min = 8, max = 100)
        String password
) {
}
```

## 8.2 Mapper

Usare mapper manuali o MapStruct, in base allo stile del progetto.

Esempio mapper manuale:

```java
@Component
public class UserMapper {

    public UserDto toDto(User user) {
        return new UserDto(
                user.getId(),
                user.getUsername(),
                user.getEmail(),
                user.isEnabled()
        );
    }

    public User toEntity(CreateUserRequest request) {
        return User.builder()
                .username(request.username())
                .email(request.email())
                .enabled(true)
                .build();
    }

    public void updateEntity(User user, UpdateUserRequest request) {
        user.setEmail(request.email());
        user.setEnabled(request.enabled());
    }
}
```

---

# 9. REST API Design

## 9.1 Convenzioni endpoint

Usare URI orientati alle risorse.

Esempi:

```text
GET    /api/users
GET    /api/users/{id}
POST   /api/users
PUT    /api/users/{id}
PATCH  /api/users/{id}/status
DELETE /api/users/{id}
```

Evitare endpoint non REST quando non necessari:

```text
NO: /api/getUsers
NO: /api/createUser
NO: /api/deleteUserById
```

## 9.2 Status HTTP

Usare status coerenti:

```text
200 OK                    Lettura o aggiornamento con body
201 Created               Creazione riuscita
204 No Content            Cancellazione riuscita o update senza body
400 Bad Request           Request non valida
401 Unauthorized          Utente non autenticato
403 Forbidden             Utente non autorizzato
404 Not Found             Risorsa non trovata
409 Conflict              Conflitto di business
422 Unprocessable Entity  Validazione semantica fallita, se adottato dal progetto
500 Internal Server Error Errore inatteso
```

## 9.3 Paginazione

Per liste potenzialmente grandi usare paginazione.

Esempio:

```text
GET /api/users?page=0&size=20&sort=username,asc
```

Response consigliata:

```json
{
  "content": [],
  "page": 0,
  "size": 20,
  "totalElements": 100,
  "totalPages": 5
}
```

## 9.4 Filtri

Per ricerche semplici usare query parameters.

Esempio:

```text
GET /api/users?email=mario&enabled=true
```

Per ricerche complesse valutare POST su endpoint dedicato:

```text
POST /api/users/search
```

---

# 10. Validazione ed error handling

## 10.1 Validazione backend

Usare Bean Validation sui DTO.

Esempi:

```java
@NotBlank
@Size(max = 100)
private String name;

@NotNull
@Positive
private BigDecimal amount;

@Email
private String email;
```

## 10.2 Gestione centralizzata errori

Usare `@RestControllerAdvice`.

Esempio:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleNotFound(ResourceNotFoundException ex) {
        return ErrorResponse.of("RESOURCE_NOT_FOUND", ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ValidationErrorResponse handleValidation(MethodArgumentNotValidException ex) {
        List<FieldErrorDto> errors = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(error -> new FieldErrorDto(
                        error.getField(),
                        error.getDefaultMessage()
                ))
                .toList();

        return new ValidationErrorResponse("VALIDATION_ERROR", errors);
    }
}
```

Errore standard consigliato:

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Request validation failed",
  "fields": [
    {
      "field": "email",
      "message": "must be a well-formed email address"
    }
  ]
}
```

---

# 11. Sicurezza

## 11.1 Principi

Claude deve trattare la sicurezza come requisito trasversale.

Regole:

- non salvare password in chiaro;
- usare hashing sicuro per password;
- proteggere endpoint sensibili;
- validare input lato server;
- non esporre stack trace in produzione;
- evitare informazioni sensibili nei log;
- usare CORS in modo controllato;
- usare HTTPS in produzione;
- applicare controlli di autorizzazione lato backend, non solo lato frontend.

## 11.2 Autenticazione e autorizzazione

Se il progetto usa JWT:

- frontend salva e invia token secondo il pattern già adottato;
- backend valida token;
- ruoli e permessi vengono controllati lato server;
- `401` indica utente non autenticato;
- `403` indica utente autenticato ma non autorizzato.

Esempi di ruoli:

```text
ROLE_ADMIN
ROLE_USER
ROLE_MANAGER
```

## 11.3 Multitenancy

Se il progetto è multitenant, Claude deve:

- evitare accesso cross-tenant;
- filtrare sempre i dati per tenant;
- non fidarsi del tenant passato dal client;
- derivare il tenant dal contesto autenticato quando possibile;
- applicare il filtro tenant a livello service/repository;
- includere test per verificare isolamento dati.

Pattern possibili:

1. **tenant_id su ogni tabella principale**
2. **schema separato per tenant**
3. **database separato per tenant**

La scelta deve rispettare l'architettura già adottata.

---

# 12. Logging

Il logging deve essere utile ma non eccessivo.

Regole:

- usare logger, non `System.out.println`;
- loggare eventi applicativi rilevanti;
- non loggare password, token, dati sanitari o dati sensibili;
- usare livelli corretti: `debug`, `info`, `warn`, `error`;
- includere correlation id/request id se il progetto lo supporta.

Esempio:

```java
private static final Logger log = LoggerFactory.getLogger(UserService.class);

log.info("Creating user with username={}", request.username());
```

---

# 13. Test

## 13.1 Backend

Claude deve generare test quando modifica logica significativa.

Tipologie:

- unit test per service e mapper;
- test repository con database di test;
- test controller con MockMvc;
- integration test per flussi principali.

Framework attesi:

- JUnit;
- Mockito;
- Spring Boot Test;
- Testcontainers, se già presente.

## 13.2 Frontend

Per Angular, generare test quando utile.

Tipologie:

- test componenti;
- test service;
- test guard;
- test pipe;
- test form validation.

Controllare la configurazione reale del progetto prima di assumere strumenti specifici.

---

# 14. Comandi di sviluppo

Claude deve verificare nel repository reale quali comandi sono presenti in `package.json`, `pom.xml`, `Makefile` o script dedicati.

Comandi tipici frontend:

```bash
cd frontend
npm install
npm start
npm run build
npm test
npm run lint
```

Comandi tipici backend:

```bash
cd backend
./mvnw clean install
./mvnw spring-boot:run
./mvnw test
```

Oppure, se non esiste `mvnw`:

```bash
mvn clean install
mvn spring-boot:run
mvn test
```

Comandi Docker tipici:

```bash
docker compose up -d
docker compose logs -f
docker compose down
```

Claude non deve inventare comandi se nel repository esistono script specifici. Deve preferire sempre i comandi presenti nel progetto.

---

# 15. Configurazione ambienti

## 15.1 Frontend

Usare file environment per configurare endpoint API.

Esempio:

```typescript
export const environment = {
  production: false,
  apiBaseUrl: 'http://localhost:8080/api'
};
```

## 15.2 Backend

Usare `application.yml` o profili Spring.

Esempio:

```yaml
spring:
  profiles:
    active: dev

  datasource:
    url: jdbc:postgresql://localhost:5432/appdb
    username: app
    password: app

  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
```

Regole:

- non salvare segreti reali nel repository;
- usare variabili ambiente;
- usare profili `dev`, `test`, `prod`;
- in produzione evitare `ddl-auto: update`;
- preferire migrazioni versionate.

---

# 16. Performance

## 16.1 Backend

Prestare attenzione a:

- paginazione;
- N+1 query;
- query troppo ampie;
- serializzazione di grafi JPA;
- indici database;
- transazioni troppo lunghe;
- caricamento inutile di relazioni.

## 16.2 Frontend

Prestare attenzione a:

- lazy loading delle feature;
- componenti troppo grandi;
- rendering di liste molto lunghe;
- chiamate HTTP duplicate;
- gestione loading;
- caching quando utile;
- bundle size.

---

# 17. Accessibilità e UX

Quando Claude lavora sul frontend deve:

- usare label associate ai campi;
- prevedere messaggi di errore comprensibili;
- non basarsi solo sul colore;
- usare pulsanti con testo chiaro;
- gestire stato loading;
- gestire stato vuoto;
- gestire stato errore;
- rendere le tabelle leggibili;
- mantenere la UI coerente.

---

# 18. Workflow consigliato per Claude

Quando ricevi una richiesta di modifica:

1. Analizza i file rilevanti.
2. Identifica frontend, backend o entrambi.
3. Verifica pattern esistenti nel progetto.
4. Proponi o applica modifiche coerenti.
5. Aggiorna DTO, service, mapper, repository e componenti se necessario.
6. Aggiorna test se la logica cambia.
7. Verifica build/test se possibile.
8. Riassumi le modifiche effettuate.
9. Segnala eventuali rischi o passaggi manuali.

Claude deve evitare di modificare molti file senza una ragione chiara.

---

# 19. Convenzioni di naming

## 19.1 Backend Java

Classi:

```text
UserController
UserService
UserRepository
UserMapper
UserDto
CreateUserRequest
UpdateUserRequest
ResourceNotFoundException
GlobalExceptionHandler
```

Package:

```text
controller
service
repository
entity
dto
mapper
exception
config
security
```

## 19.2 Frontend Angular

File:

```text
user-list.component.ts
user-detail.component.ts
user-form.component.ts
user.service.ts
user.model.ts
user.routes.ts
```

Classi:

```text
UserListComponent
UserDetailComponent
UserFormComponent
UserService
```

---

# 20. Criteri per nuove funzionalità CRUD

Quando Claude deve creare una nuova funzionalità CRUD completa, deve considerare:

## Backend

- entity;
- migration database;
- repository;
- DTO request/response;
- mapper;
- service;
- controller;
- gestione errori;
- validazioni;
- test.

## Frontend

- model TypeScript;
- service HTTP;
- route;
- lista;
- dettaglio;
- form creazione/modifica;
- gestione errori;
- loading state;
- conferma cancellazione;
- eventuale paginazione;
- eventuale filtro di ricerca.

## API

- endpoint REST coerenti;
- status HTTP corretti;
- payload chiari;
- gestione validazioni.

---

# 21. Esempio flusso end-to-end

Per una risorsa `Customer`, il flusso corretto è:

```text
Angular Component
    -> Angular Service
        -> HTTP REST API
            -> Spring Controller
                -> Spring Service
                    -> Repository JPA
                        -> Database
                    <- Entity
                <- DTO
        <- JSON response
    <- ViewModel/UI
```

Nessun componente Angular deve conoscere dettagli Hibernate.
Nessun controller Spring deve conoscere dettagli visuali Angular.
Nessuna entity JPA deve essere esposta direttamente al client.

---

# 22. Regole per modifiche al database

Prima di modificare il modello dati, Claude deve:

- verificare entity esistenti;
- verificare migrazioni esistenti;
- capire se ci sono dati già in produzione;
- evitare modifiche distruttive;
- usare script incrementali;
- aggiornare repository, DTO, mapper e frontend;
- valutare impatto su API esistenti.

---

# 23. Regole per refactoring

Claude può proporre refactoring quando:

- riduce duplicazione;
- migliora leggibilità;
- migliora sicurezza;
- risolve bug;
- semplifica test;
- allinea codice a pattern già usati.

Claude deve evitare refactoring estetici non richiesti su ampie parti del progetto.

---

# 24. Gestione errori frontend

Il frontend deve gestire:

- `400`: errori di validazione;
- `401`: sessione scaduta o non autenticata;
- `403`: accesso negato;
- `404`: risorsa non trovata;
- `409`: conflitto;
- `500`: errore inatteso.

Prevedere messaggi leggibili per l'utente, evitando dettagli tecnici.

Esempio:

```text
Impossibile salvare i dati. Controlla i campi evidenziati.
Accesso non autorizzato.
Risorsa non trovata.
Si è verificato un errore inatteso. Riprova più tardi.
```

---

# 25. API contract tra Angular e Spring Boot

Quando Claude modifica un endpoint backend deve verificare anche:

- service Angular corrispondente;
- model TypeScript;
- form o componente che usa l'endpoint;
- eventuali test;
- eventuali mock.

Quando Claude modifica un model frontend deve verificare se il DTO backend è coerente.

---

# 26. Documentazione

Aggiornare la documentazione quando:

- cambia un endpoint API;
- cambia una configurazione;
- cambia un flusso applicativo;
- viene aggiunta una nuova funzionalità importante;
- cambia il modello dati;
- vengono introdotte nuove variabili ambiente.

Documenti tipici:

```text
README.md
docs/API.md
docs/ARCHITECTURE.md
docs/DEPLOYMENT.md
```

---

# 27. Cose da non fare

Claude non deve:

- introdurre dipendenze senza motivazione;
- esporre entity JPA nelle API;
- mettere logica di business nei controller;
- creare query SQL vulnerabili;
- salvare segreti nel codice;
- modificare migrazioni già eseguite;
- ignorare test rotti;
- cancellare codice senza verificarne l'uso;
- cambiare architettura senza richiesta;
- creare componenti Angular monolitici;
- usare `any` in TypeScript senza motivo;
- usare `EAGER` come soluzione rapida a problemi di lazy loading;
- nascondere errori con catch generici;
- restituire sempre `200 OK` anche per errori applicativi;
- usare `System.out.println` per logging.

---

# 28. Criteri di qualità prima di concludere

Prima di terminare una modifica, Claude deve controllare:

- il codice compila;
- i test rilevanti passano, se eseguibili;
- frontend e backend sono coerenti;
- i DTO sono aggiornati;
- gli endpoint sono coerenti;
- gli errori sono gestiti;
- non sono stati introdotti segreti;
- non sono stati introdotti warning evidenti;
- il codice segue lo stile del progetto.

---

# 29. Risposte attese da Claude

Quando Claude completa una modifica deve rispondere in modo sintetico ma utile, indicando:

1. file modificati;
2. motivazione delle modifiche;
3. eventuali test eseguiti;
4. eventuali test non eseguiti e motivo;
5. eventuali passi successivi.

Esempio:

```text
Modifiche effettuate:
- aggiunto UserController;
- aggiunto UserService;
- aggiunti DTO di creazione e risposta;
- aggiornato UserService Angular;
- aggiunta gestione errore 404.

Test:
- eseguito mvn test con esito positivo.
- non eseguiti test Angular perché non configurati nel repository.

Note:
- verificare la configurazione CORS per ambiente di produzione.
```

---

# 30. Istruzioni specifiche per task frequenti

## 30.1 Aggiungere una nuova entity

Quando aggiungi una nuova entity:

1. crea entity JPA;
2. crea migration;
3. crea repository;
4. crea DTO;
5. crea mapper;
6. crea service;
7. crea controller;
8. aggiungi test;
9. aggiorna frontend se necessario.

## 30.2 Aggiungere un nuovo endpoint

Quando aggiungi un endpoint:

1. definisci request/response DTO;
2. aggiungi metodo nel controller;
3. implementa logica nel service;
4. aggiorna repository se serve;
5. gestisci errori;
6. aggiorna service Angular;
7. aggiorna model TypeScript;
8. aggiorna UI;
9. aggiungi test.

## 30.3 Correggere un bug

Quando correggi un bug:

1. riproduci o capisci il problema;
2. individua la causa;
3. applica la modifica minima;
4. aggiungi o aggiorna test;
5. verifica eventuali regressioni;
6. spiega chiaramente la causa e la soluzione.

## 30.4 Ottimizzare una query

Quando ottimizzi una query:

1. identifica il problema;
2. verifica relazioni JPA;
3. valuta N+1;
4. valuta indici;
5. usa projection, join fetch o entity graph se appropriato;
6. mantieni la paginazione;
7. evita caricamenti eccessivi.

---

# 31. Standard minimo per commit o patch

Ogni patch deve essere:

- piccola quanto basta;
- coerente;
- leggibile;
- testabile;
- reversibile;
- documentata se necessario.

Messaggi di commit consigliati:

```text
feat(users): add user management CRUD
fix(auth): handle expired JWT token
refactor(customer): separate mapper from service
test(users): add service unit tests
docs(api): document customer endpoints
```

---

# 32. Assunzioni predefinite

Se non specificato diversamente, Claude deve assumere:

- backend Java con Spring Boot;
- persistenza con Spring Data JPA e Hibernate;
- API REST JSON;
- frontend Angular con TypeScript;
- database relazionale;
- autenticazione da verificare nel progetto;
- DTO separati dalle entity;
- architettura layered;
- build tramite Maven o wrapper Maven;
- frontend build tramite npm.

Queste assunzioni devono essere verificate sul repository prima di modificare codice reale.

---

# 33. Priorità progettuali

In caso di dubbio, privilegiare:

1. correttezza funzionale;
2. sicurezza;
3. semplicità;
4. leggibilità;
5. testabilità;
6. coerenza con il codice esistente;
7. performance;
8. astrazione.

Non introdurre complessità non necessaria.

---

# 34. Nota finale per Claude

Questo progetto deve rimanere pulito, manutenibile e coerente.

Ogni modifica deve rispettare la separazione tra:

- UI Angular;
- contratto API;
- logica applicativa Spring;
- persistenza Hibernate/JPA;
- database.

L'obiettivo non è solo far funzionare il codice, ma costruire una base solida per una web application professionale ed evolutiva.
