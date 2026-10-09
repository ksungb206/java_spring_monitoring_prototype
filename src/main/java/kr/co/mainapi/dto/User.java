package kr.co.mainapi.dto;
import java.time.LocalDateTime;
public record User(long id,String email,String name,String profileImage,int status,LocalDateTime createdAt,LocalDateTime updatedAt,LocalDateTime deletedAt) {}
