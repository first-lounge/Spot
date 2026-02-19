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
public class StoreResponse {

    private UUID id;
    private String name;
    private String roadAddress;
    private String addressDetail;
    private String phoneNumber;
    private String status;
    private Integer ownerId;
    @JsonProperty("isDeleted")
    private boolean isDeleted;
}
