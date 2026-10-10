package kr.co.mainapi;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;
import kr.co.mainapi.controller.ApiController;
import kr.co.mainapi.security.SecurityConfig;
import org.springframework.context.annotation.Import;
import kr.co.mainapi.service.OpConfigService;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(ApiController.class)
@Import(SecurityConfig.class)
@AutoConfigureMockMvc
class HealthTest {
    @Autowired MockMvc mvc;
    @MockBean OpConfigService service;

    @Test void health() throws Exception {
        mvc.perform(get("/api/v1/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code").value(200))
            .andExpect(jsonPath("$.data.status").value("result_ok_deploy_v2"));
    }

    @Test void opConfigIsForbidden() throws Exception {
        mvc.perform(get("/api/v1/op-config"))
            .andExpect(status().isForbidden());
    }
}
