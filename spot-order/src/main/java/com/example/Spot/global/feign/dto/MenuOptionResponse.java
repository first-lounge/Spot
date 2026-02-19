package com.example.Spot.global.feign.dto;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class MenuOptionResponse {

    private UUID id;
    private UUID menuId;
    private String name;
    private String detail;
    private Integer price;
    @JsonProperty("isDeleted")
    private boolean isDeleted;
}
