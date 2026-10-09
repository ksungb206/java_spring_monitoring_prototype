package kr.co.mainapi.dto;
public record ApiResponse<T>(int code,String message,T data) {
 public static <T> ApiResponse<T> success(T data) {return new ApiResponse<>(200,"success",data);}
}
