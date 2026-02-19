package com.example.Spot.order.presentation.dto.response;

import java.io.Serial;
import java.io.Serializable;
import java.util.Map;
import java.util.UUID;

import com.example.Spot.global.feign.dto.MenuOptionResponse;
import com.example.Spot.global.feign.dto.MenuResponse;
import com.example.Spot.global.feign.dto.StoreResponse;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderContextDto implements Serializable {
    
    @Serial
    private static final long serialVersionUID = 1L;
    
    private StoreResponse store;
    private Map<UUID, MenuResponse> menuMap;
    private Map<UUID, MenuOptionResponse> optionMap;

    public java.math.BigDecimal calculateTotalAmount(com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto request) {
        java.math.BigDecimal total = java.math.BigDecimal.ZERO;

        if (request.getOrderItems() == null) {
            return total;
        }

        for (var item : request.getOrderItems()) {
            // 1. 메뉴 가격 계산
            MenuResponse menu = this.menuMap.get(item.getMenuId());
            if (menu != null) {
                java.math.BigDecimal itemSubtotal = java.math.BigDecimal.valueOf(menu.getPrice())
                        .multiply(java.math.BigDecimal.valueOf(item.getQuantity()));
                total = total.add(itemSubtotal);
            }

            // 2. 옵션 가격 합산
            if (item.getOptions() != null) {
                for (var opt : item.getOptions()) {
                    MenuOptionResponse option = this.optionMap.get(opt.getMenuOptionId());
                    if (option != null) {
                        total = total.add(java.math.BigDecimal.valueOf(option.getPrice()));
                    }
                }
            }
        }
        return total;
    }
}
