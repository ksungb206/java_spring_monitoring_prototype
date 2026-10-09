package kr.co.mainapi.security;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
@Configuration
public class SecurityConfig {
 @Bean SecurityFilterChain chain(HttpSecurity http,TokenFilter tokenFilter) throws Exception {
  return http.csrf(csrf->csrf.disable())
   .sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
   .authorizeHttpRequests(a->a.requestMatchers("/api/v1/health","/api/v1/login").permitAll().anyRequest().authenticated())
   .addFilterBefore(tokenFilter,UsernamePasswordAuthenticationFilter.class).build();
 }
}
