package kr.co.mainapi;
import org.junit.jupiter.api.Test;
import kr.co.mainapi.service.UserService;
import kr.co.mainapi.mapper.UserMapper;
import static org.mockito.Mockito.*;
class UserServiceTest {
 @Test void pageSizeIsCappedAt100() {
  UserMapper mapper=mock(UserMapper.class);
  new UserService(mapper).list(null,500);
  verify(mapper).findPage(null,100);
 }
}
