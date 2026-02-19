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
public class MenuResponse {

    private UUID id;
    private UUID storeId;
    private String name;
    private String description;
    private Integer price;
    private String imageUrl;
    @JsonProperty("isHidden")
    private boolean isHidden;
    @JsonProperty("isDeleted")
    private boolean isDeleted;
}
