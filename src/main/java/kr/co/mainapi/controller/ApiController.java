package kr.co.mainapi.controller;
import kr.co.mainapi.dto.ApiResponse;
import kr.co.mainapi.service.OpConfigService;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.Map;
@RestController
@RequestMapping("/api/v1")
public class ApiController {
 private final OpConfigService opConfigService;
 public ApiController(OpConfigService opConfigService){this.opConfigService=opConfigService;}
 @GetMapping("/health")
 public ApiResponse<Map<String,String>> health(){return ApiResponse.success(Map.of("status","result_ok_deploy_v2","timestamp",Instant.now().toString()));}
 @GetMapping("/op-config")
 public ApiResponse<?> opConfig(){return ApiResponse.success(opConfigService.getAll());}
}
