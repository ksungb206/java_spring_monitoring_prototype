package kr.co.mainapi.config;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@MapperScan("kr.co.mainapi.mapper")
public class MyBatisConfig {}
