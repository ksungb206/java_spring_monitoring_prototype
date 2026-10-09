package kr.co.mainapi.dto;
import java.time.LocalDateTime;
public record OpConfig(long id, String name, String key, String value, LocalDateTime createdAt) {}
