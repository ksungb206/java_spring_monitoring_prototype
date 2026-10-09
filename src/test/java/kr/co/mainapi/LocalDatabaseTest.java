package kr.co.mainapi;

import kr.co.mainapi.mapper.OpConfigMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("local")
class LocalDatabaseTest {
    @Autowired OpConfigMapper mapper;

    @Test void h2MapperReadsSeedData() {
        assertFalse(mapper.findAll().isEmpty());
    }
}
