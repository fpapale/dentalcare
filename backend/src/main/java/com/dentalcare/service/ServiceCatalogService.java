package com.dentalcare.service;

import com.dentalcare.dto.AddBundleItemRequest;
import com.dentalcare.dto.ConditionDefaultDto;
import com.dentalcare.dto.CreateConditionDefaultRequest;
import com.dentalcare.dto.CreateServiceRequest;
import com.dentalcare.dto.ServiceAdminDto;
import com.dentalcare.dto.ServiceDto;
import com.dentalcare.dto.UpdateServiceRequest;
import com.dentalcare.dto.ServiceCategoryDto;
import com.dentalcare.dto.CreateServiceCategoryRequest;
import com.dentalcare.dto.UpdateServiceCategoryRequest;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ServiceCatalogService {

    private final NamedParameterJdbcTemplate jdbc;

    public ServiceCatalogService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    /** Ruoli che vedono l'intero listino: non clinici, selezionano per conto di chiunque. */
    private static final Set<String> UNFILTERED_ROLES = Set.of("secretary", "admin", "tenant_admin");

    /**
     * Ruolo su cui filtrare il listino, o null se il ruolo corrente non filtra.
     * Il ruolo arriva dal JWT, mai dal client.
     */
    private String filteringRole() {
        String role = TenantContext.getCurrentRole();
        if (role == null || role.isBlank()) {
            return null;
        }
        String normalized = role.trim().toLowerCase();
        return UNFILTERED_ROLES.contains(normalized) ? null : normalized;
    }

    public List<ServiceDto> findAll() {
        return findAll(null);
    }

    public List<ServiceDto> findAll(Integer toothFdi) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);

        String toothFilter = "";
        if (toothFdi != null) {
            int digit = toothFdi % 10;
            boolean isDeciduous = toothFdi / 10 >= 5;
            params.addValue("digit", digit);
            params.addValue("isDeciduous", isDeciduous);
            toothFilter = """
                AND (min_tooth_digit IS NULL OR :digit >= min_tooth_digit)
                AND (max_tooth_digit IS NULL OR :digit <= max_tooth_digit)
                AND (:isDeciduous = false OR applicable_to_deciduous = true)
                """;
        }

        // Filtro per ruolo: una categoria con allowed_roles valorizzato è selezionabile
        // solo dai ruoli elencati. Categoria assente o senza vincolo = visibile a tutti.
        String roleFilter = "";
        String role = filteringRole();
        if (role != null) {
            params.addValue("role", role);
            roleFilter = """
                AND NOT EXISTS (
                    SELECT 1 FROM %s.service_categories cat
                    WHERE cat.clinic_id = sc.clinic_id
                      AND lower(cat.name) = lower(sc.category)
                      AND btrim(coalesce(cat.allowed_roles, '')) <> ''
                      AND :role <> ALL (string_to_array(lower(replace(cat.allowed_roles, ' ', '')), ','))
                )
                """.formatted(s());
        }

        String sql = """
            SELECT sc.id, sc.code, sc.name, sc.category, sc.default_price, sc.duration_minutes
            FROM %s.service_catalog sc
            WHERE sc.clinic_id = :clinicId
              AND sc.active = true
            """.formatted(s()) + toothFilter + roleFilter + """
            ORDER BY sc.category, sc.name
            """;

        return jdbc.query(sql, params, (rs, n) -> new ServiceDto(
                rs.getObject("id", UUID.class),
                rs.getString("code"),
                rs.getString("name"),
                rs.getString("category"),
                rs.getBigDecimal("default_price"),
                rs.getObject("duration_minutes", Integer.class)
        ));
    }

    public List<ServiceDto> findConditionDefaults(String conditionName) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT sc.id, sc.code, sc.name, sc.category, sc.default_price, sc.duration_minutes
            FROM %s.condition_service_defaults csd
            JOIN %s.service_catalog sc ON sc.id = csd.service_id AND sc.clinic_id = csd.clinic_id
            WHERE csd.condition_name = :conditionName AND csd.clinic_id = :clinicId AND sc.active = true
            ORDER BY csd.sort_order
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("conditionName", conditionName).addValue("clinicId", clinicId),
                (rs, n) -> new ServiceDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("code"),
                        rs.getString("name"),
                        rs.getString("category"),
                        rs.getBigDecimal("default_price"),
                        rs.getObject("duration_minutes", Integer.class)
                ));
    }

    public List<ServiceDto> findBundleItems(UUID serviceId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT sc.id, sc.code, sc.name, sc.category, sc.default_price, sc.duration_minutes
            FROM %s.service_bundle_items sbi
            JOIN %s.service_catalog sc ON sc.id = sbi.child_service_id AND sc.clinic_id = sbi.clinic_id
            WHERE sbi.parent_service_id = :serviceId AND sbi.clinic_id = :clinicId AND sc.active = true
            ORDER BY sbi.sort_order
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("serviceId", serviceId).addValue("clinicId", clinicId),
                (rs, n) -> new ServiceDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("code"),
                        rs.getString("name"),
                        rs.getString("category"),
                        rs.getBigDecimal("default_price"),
                        rs.getObject("duration_minutes", Integer.class)
                ));
    }

    // ── Admin: Services CRUD ─────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ServiceAdminDto> listAdmin() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String sql = """
            SELECT id, code, name, category, description, default_price, default_vat_rate,
                   duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous, active
            FROM %s.service_catalog
            WHERE clinic_id = :clinicId
            ORDER BY category, name
            """.formatted(s());

        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId),
                (rs, n) -> mapAdminRow(rs));
    }

    @Transactional
    public ServiceAdminDto create(CreateServiceRequest r) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();

        jdbc.update("""
            INSERT INTO %s.service_catalog
                (id, clinic_id, code, name, category, description, default_price, default_vat_rate,
                 duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous, active)
            VALUES
                (:id, :clinicId, :code, :name, :category, :description, :defaultPrice, :defaultVatRate,
                 :durationMinutes, :minToothDigit, :maxToothDigit, :applicableToDeciduous, true)
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("code", r.code())
                        .addValue("name", r.name())
                        .addValue("category", r.category())
                        .addValue("description", r.description())
                        .addValue("defaultPrice", r.defaultPrice())
                        .addValue("defaultVatRate", r.defaultVatRate() != null ? r.defaultVatRate() : BigDecimal.ZERO)
                        .addValue("durationMinutes", r.durationMinutes())
                        .addValue("minToothDigit", r.minToothDigit())
                        .addValue("maxToothDigit", r.maxToothDigit())
                        .addValue("applicableToDeciduous", r.applicableToDeciduous() != null ? r.applicableToDeciduous() : true));

        return findAdminById(id, clinicId);
    }

    @Transactional
    public ServiceAdminDto update(UUID id, UpdateServiceRequest r) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        int rows = jdbc.update("""
            UPDATE %s.service_catalog
            SET name                    = :name,
                category                = :category,
                description             = :description,
                default_price           = :defaultPrice,
                default_vat_rate        = :defaultVatRate,
                duration_minutes        = :durationMinutes,
                min_tooth_digit         = :minToothDigit,
                max_tooth_digit         = :maxToothDigit,
                applicable_to_deciduous = :applicableToDeciduous,
                active                  = :active,
                updated_at              = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("name", r.name())
                        .addValue("category", r.category())
                        .addValue("description", r.description())
                        .addValue("defaultPrice", r.defaultPrice())
                        .addValue("defaultVatRate", r.defaultVatRate() != null ? r.defaultVatRate() : BigDecimal.ZERO)
                        .addValue("durationMinutes", r.durationMinutes())
                        .addValue("minToothDigit", r.minToothDigit())
                        .addValue("maxToothDigit", r.maxToothDigit())
                        .addValue("applicableToDeciduous", r.applicableToDeciduous() != null ? r.applicableToDeciduous() : true)
                        .addValue("active", r.active()));

        if (rows == 0) {
            throw new ResourceNotFoundException("Service not found: " + id);
        }
        return findAdminById(id, clinicId);
    }

    @Transactional
    public void delete(UUID id) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId);

        boolean referenced = Boolean.TRUE.equals(jdbc.queryForObject("""
            SELECT EXISTS (
                SELECT 1 FROM %s.estimate_lines WHERE service_id = :id AND clinic_id = :clinicId
                UNION ALL
                SELECT 1 FROM %s.treatment_plan_items WHERE service_id = :id AND clinic_id = :clinicId
            )
            """.formatted(s(), s()), params, Boolean.class));

        if (referenced) {
            int rows = jdbc.update("""
                UPDATE %s.service_catalog
                SET active = false, updated_at = now()
                WHERE id = :id AND clinic_id = :clinicId
                """.formatted(s()), params);
            if (rows == 0) {
                throw new ResourceNotFoundException("Service not found: " + id);
            }
            return;
        }

        int rows = jdbc.update("""
            DELETE FROM %s.service_catalog
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()), params);

        if (rows == 0) {
            throw new ResourceNotFoundException("Service not found: " + id);
        }
    }

    private ServiceAdminDto findAdminById(UUID id, UUID clinicId) {
        String sql = """
            SELECT id, code, name, category, description, default_price, default_vat_rate,
                   duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous, active
            FROM %s.service_catalog
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s());

        List<ServiceAdminDto> rows = jdbc.query(sql,
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                (rs, n) -> mapAdminRow(rs));

        if (rows.isEmpty()) {
            throw new ResourceNotFoundException("Service not found: " + id);
        }
        return rows.get(0);
    }

    private ServiceAdminDto mapAdminRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new ServiceAdminDto(
                rs.getObject("id", UUID.class),
                rs.getString("code"),
                rs.getString("name"),
                rs.getString("category"),
                rs.getString("description"),
                rs.getBigDecimal("default_price"),
                rs.getBigDecimal("default_vat_rate"),
                rs.getObject("duration_minutes", Integer.class),
                rs.getObject("min_tooth_digit", Integer.class),
                rs.getObject("max_tooth_digit", Integer.class),
                rs.getBoolean("applicable_to_deciduous"),
                rs.getBoolean("active")
        );
    }

    // ── Admin: Condition defaults CRUD ───────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ConditionDefaultDto> listConditionDefaults() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String sql = """
            SELECT csd.id, csd.condition_name, csd.service_id, sc.name AS service_name, csd.sort_order
            FROM %s.condition_service_defaults csd
            JOIN %s.service_catalog sc ON sc.id = csd.service_id AND sc.clinic_id = csd.clinic_id
            WHERE csd.clinic_id = :clinicId
            ORDER BY csd.condition_name, csd.sort_order
            """.formatted(s(), s());

        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId),
                (rs, n) -> new ConditionDefaultDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("condition_name"),
                        rs.getObject("service_id", UUID.class),
                        rs.getString("service_name"),
                        rs.getInt("sort_order")
                ));
    }

    @Transactional
    public ConditionDefaultDto addConditionDefault(CreateConditionDefaultRequest r) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();

        jdbc.update("""
            INSERT INTO %s.condition_service_defaults
                (id, clinic_id, condition_name, service_id, sort_order)
            VALUES
                (:id, :clinicId, :conditionName, :serviceId, :sortOrder)
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("conditionName", r.conditionName())
                        .addValue("serviceId", r.serviceId())
                        .addValue("sortOrder", r.sortOrder() != null ? r.sortOrder() : 10));

        String sql = """
            SELECT csd.id, csd.condition_name, csd.service_id, sc.name AS service_name, csd.sort_order
            FROM %s.condition_service_defaults csd
            JOIN %s.service_catalog sc ON sc.id = csd.service_id AND sc.clinic_id = csd.clinic_id
            WHERE csd.id = :id AND csd.clinic_id = :clinicId
            """.formatted(s(), s());

        List<ConditionDefaultDto> rows = jdbc.query(sql,
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                (rs, n) -> new ConditionDefaultDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("condition_name"),
                        rs.getObject("service_id", UUID.class),
                        rs.getString("service_name"),
                        rs.getInt("sort_order")
                ));

        if (rows.isEmpty()) {
            throw new ResourceNotFoundException("Condition default not found: " + id);
        }
        return rows.get(0);
    }

    @Transactional
    public void deleteConditionDefault(UUID id) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        int rows = jdbc.update("""
            DELETE FROM %s.condition_service_defaults
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId));

        if (rows == 0) {
            throw new ResourceNotFoundException("Condition default not found: " + id);
        }
    }

    // ── Admin: Bundle items CRUD ─────────────────────────────────────────────

    @Transactional
    public void addBundleItem(UUID parentServiceId, AddBundleItemRequest r) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();

        jdbc.update("""
            INSERT INTO %s.service_bundle_items
                (id, clinic_id, parent_service_id, child_service_id, sort_order)
            VALUES
                (:id, :clinicId, :parentServiceId, :childServiceId, :sortOrder)
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("parentServiceId", parentServiceId)
                        .addValue("childServiceId", r.childServiceId())
                        .addValue("sortOrder", r.sortOrder() != null ? r.sortOrder() : 10));
    }

    @Transactional
    public void deleteBundleItem(UUID itemId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        int rows = jdbc.update("""
            DELETE FROM %s.service_bundle_items
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource().addValue("id", itemId).addValue("clinicId", clinicId));

        if (rows == 0) {
            throw new ResourceNotFoundException("Bundle item not found: " + itemId);
        }
    }

    // ── Admin: Categorie prestazioni CRUD ────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ServiceCategoryDto> listCategories() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT c.id, c.name, c.sort_order, c.active, c.allowed_roles,
                   (SELECT count(*) FROM %s.service_catalog sc
                     WHERE sc.clinic_id = c.clinic_id AND sc.category = c.name) AS usage_count
            FROM %s.service_categories c
            WHERE c.clinic_id = :clinicId
            ORDER BY c.sort_order, c.name
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId),
                (rs, n) -> mapCategoryRow(rs));
    }

    @Transactional
    public ServiceCategoryDto createCategory(CreateServiceCategoryRequest r) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO %s.service_categories (id, clinic_id, name, sort_order, allowed_roles)
            VALUES (:id, :clinicId, :name, :sortOrder, :allowedRoles)
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("name", r.name())
                        .addValue("sortOrder", r.sortOrder() != null ? r.sortOrder() : 10)
                        .addValue("allowedRoles", joinRoles(r.allowedRoles()), java.sql.Types.VARCHAR));
        return findCategoryById(id, clinicId);
    }

    @Transactional
    public ServiceCategoryDto updateCategory(UUID id, UpdateServiceCategoryRequest r) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        List<String> oldNames = jdbc.queryForList("""
            SELECT name FROM %s.service_categories WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                String.class);
        if (oldNames.isEmpty()) {
            throw new ResourceNotFoundException("Category not found: " + id);
        }
        String oldName = oldNames.get(0);

        jdbc.update("""
            UPDATE %s.service_categories
            SET name = :name, sort_order = :sortOrder, active = :active,
                allowed_roles = :allowedRoles, updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("name", r.name())
                        .addValue("sortOrder", r.sortOrder() != null ? r.sortOrder() : 10)
                        .addValue("active", r.active())
                        .addValue("allowedRoles", joinRoles(r.allowedRoles()), java.sql.Types.VARCHAR));

        if (!oldName.equals(r.name())) {
            jdbc.update("""
                UPDATE %s.service_catalog
                SET category = :newName, updated_at = now()
                WHERE category = :oldName AND clinic_id = :clinicId
                """.formatted(s()),
                    new MapSqlParameterSource()
                            .addValue("newName", r.name())
                            .addValue("oldName", oldName)
                            .addValue("clinicId", clinicId));
        }
        return findCategoryById(id, clinicId);
    }

    @Transactional
    public void deleteCategory(UUID id) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        List<String> names = jdbc.queryForList("""
            SELECT name FROM %s.service_categories WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                String.class);
        if (names.isEmpty()) {
            throw new ResourceNotFoundException("Category not found: " + id);
        }
        boolean inUse = Boolean.TRUE.equals(jdbc.queryForObject("""
            SELECT EXISTS (SELECT 1 FROM %s.service_catalog
                            WHERE category = :name AND clinic_id = :clinicId)
            """.formatted(s()),
                new MapSqlParameterSource().addValue("name", names.get(0)).addValue("clinicId", clinicId),
                Boolean.class));
        if (inUse) {
            jdbc.update("""
                UPDATE %s.service_categories SET active = false, updated_at = now()
                WHERE id = :id AND clinic_id = :clinicId
                """.formatted(s()),
                    new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId));
        } else {
            jdbc.update("""
                DELETE FROM %s.service_categories WHERE id = :id AND clinic_id = :clinicId
                """.formatted(s()),
                    new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId));
        }
    }

    private ServiceCategoryDto findCategoryById(UUID id, UUID clinicId) {
        String sql = """
            SELECT c.id, c.name, c.sort_order, c.active, c.allowed_roles,
                   (SELECT count(*) FROM %s.service_catalog sc
                     WHERE sc.clinic_id = c.clinic_id AND sc.category = c.name) AS usage_count
            FROM %s.service_categories c
            WHERE c.id = :id AND c.clinic_id = :clinicId
            """.formatted(s(), s());
        List<ServiceCategoryDto> rows = jdbc.query(sql,
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                (rs, n) -> mapCategoryRow(rs));
        if (rows.isEmpty()) {
            throw new ResourceNotFoundException("Category not found: " + id);
        }
        return rows.get(0);
    }

    private ServiceCategoryDto mapCategoryRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new ServiceCategoryDto(
                rs.getObject("id", UUID.class),
                rs.getString("name"),
                rs.getInt("sort_order"),
                rs.getBoolean("active"),
                rs.getLong("usage_count"),
                splitRoles(rs.getString("allowed_roles"))
        );
    }

    /** CSV persistito → lista di ruoli normalizzati. Null/vuoto → lista vuota (nessun vincolo). */
    private static List<String> splitRoles(String csv) {
        if (csv == null || csv.isBlank()) {
            return List.of();
        }
        return Arrays.stream(csv.split(","))
                .map(String::trim)
                .filter(r -> !r.isEmpty())
                .map(String::toLowerCase)
                .distinct()
                .toList();
    }

    /** Lista di ruoli → CSV normalizzato, o null se nessun vincolo. */
    private static String joinRoles(List<String> roles) {
        if (roles == null || roles.isEmpty()) {
            return null;
        }
        String csv = roles.stream()
                .filter(r -> r != null && !r.isBlank())
                .map(r -> r.trim().toLowerCase())
                .distinct()
                .collect(Collectors.joining(","));
        return csv.isEmpty() ? null : csv;
    }
}
