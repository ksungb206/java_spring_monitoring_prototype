package kr.co.mainapi.controller;
import kr.co.mainapi.dto.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import kr.co.mainapi.service.OpConfigService;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.Map;
@Tag(name = "Main API", description = "Health and operation configuration endpoints")
@RestController
@RequestMapping("/api/v1")
public class ApiController {
 private final OpConfigService opConfigService;
 public ApiController(OpConfigService opConfigService){this.opConfigService=opConfigService;}
 @Operation(summary = "Health check", description = "Returns the API health status and current timestamp")
 @GetMapping("/health")
 public ApiResponse<Map<String,String>> health(){return ApiResponse.success(Map.of("status","result_ok_deploy_v2","timestamp",Instant.now().toString()));}
 @Operation(summary = "Operation configuration", description = "Returns operation configuration (access restricted by Spring Security)")
 @GetMapping("/op-config")
 public ApiResponse<?> opConfig(){return ApiResponse.success(opConfigService.getAll());}
}
