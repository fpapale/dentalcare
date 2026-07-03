package com.dentalcare.service;

import com.dentalcare.dto.CreateProductCategoryRequest;
import com.dentalcare.dto.ProductCategoryDto;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProductCategoryServiceTest {

    @Mock
    NamedParameterJdbcTemplate jdbc;

    @InjectMocks
    ProductService service;

    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UUID categoryId = UUID.fromString("00000000-0000-0000-0000-000000000002");
    private final UUID providerId = UUID.fromString("00000000-0000-0000-0000-000000000004");

    @BeforeEach
    void setupContext() {
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(providerId.toString(), null, List.of()));
    }

    @AfterEach
    void clearContext() {
        TenantContext.clear();
        SecurityContextHolder.clearContext();
    }

    @Test
    void createCategory_insertsAndReturnsDtoWithName() {
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(1);

        ProductCategoryDto result = service.createCategory(new CreateProductCategoryRequest("Anestetici"));

        assertThat(result.name()).isEqualTo("Anestetici");
        assertThat(result.categoryId()).isNotNull();
        verify(jdbc).update(contains("INSERT INTO t_abcd1234.product_categories"), any(MapSqlParameterSource.class));
    }

    @Test
    void updateCategory_returnsUpdatedDto() {
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(1);

        ProductCategoryDto result = service.updateCategory(categoryId, new CreateProductCategoryRequest("Guanti"));

        assertThat(result.categoryId()).isEqualTo(categoryId);
        assertThat(result.name()).isEqualTo("Guanti");
        verify(jdbc).update(contains("UPDATE t_abcd1234.product_categories"), any(MapSqlParameterSource.class));
    }

    @Test
    void updateCategory_zeroRows_throwsNotFound() {
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(0);

        assertThatThrownBy(() -> service.updateCategory(categoryId, new CreateProductCategoryRequest("Guanti")))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining(categoryId.toString());
    }

    @Test
    void deleteCategory_referencedByActiveProducts_throwsIllegalState() {
        when(jdbc.queryForObject(anyString(), any(MapSqlParameterSource.class), eq(Integer.class)))
                .thenReturn(3);

        assertThatThrownBy(() -> service.deleteCategory(categoryId))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("3");

        verify(jdbc, never()).update(anyString(), any(MapSqlParameterSource.class));
    }

    @Test
    void deleteCategory_noReferences_deletesSuccessfully() {
        when(jdbc.queryForObject(anyString(), any(MapSqlParameterSource.class), eq(Integer.class)))
                .thenReturn(0);
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(1);

        service.deleteCategory(categoryId);

        verify(jdbc).update(contains("DELETE FROM t_abcd1234.product_categories"), any(MapSqlParameterSource.class));
    }

    @Test
    void deleteCategory_zeroRowsDeleted_throwsNotFound() {
        when(jdbc.queryForObject(anyString(), any(MapSqlParameterSource.class), eq(Integer.class)))
                .thenReturn(0);
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(0);

        assertThatThrownBy(() -> service.deleteCategory(categoryId))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining(categoryId.toString());
    }
}
