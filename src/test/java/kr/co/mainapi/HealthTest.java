package kr.co.mainapi;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;
import kr.co.mainapi.controller.ApiController;
import kr.co.mainapi.security.TokenFilter;
import kr.co.mainapi.service.OpConfigService;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(ApiController.class)
@AutoConfigureMockMvc(addFilters = false)
class HealthTest {
    @Autowired MockMvc mvc;
    @MockBean OpConfigService service;
    @MockBean TokenFilter tokenFilter;

    @Test void health() throws Exception {
        mvc.perform(get("/api/v1/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code").value(200))
            .andExpect(jsonPath("$.data.status").value("ok"));
    }
}
