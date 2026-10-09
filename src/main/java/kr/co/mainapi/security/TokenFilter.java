package kr.co.mainapi.security;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import javax.crypto.SecretKey;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
@Component
public class TokenFilter extends OncePerRequestFilter {
 private final SecretKey key;
 public TokenFilter(@Value("${app.jwt-secret}") String secret){key=Keys.hmacShaKeyFor(secret.getBytes(java.nio.charset.StandardCharsets.UTF_8));}
 @Override protected void doFilterInternal(HttpServletRequest req,HttpServletResponse res,FilterChain chain) throws ServletException,IOException {
  String token=req.getHeader("access_token");
  if(token!=null && !token.isBlank()){
   try {
    var claims=Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
    SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(claims.getSubject(),null,java.util.List.of()));
   } catch(Exception ignored) {SecurityContextHolder.clearContext();}
  }
  chain.doFilter(req,res);
 }
}
