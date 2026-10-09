package kr.co.mainapi.service;
import kr.co.mainapi.dto.User;
import kr.co.mainapi.mapper.UserMapper;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service
public class UserService {
 private final UserMapper mapper;
 public UserService(UserMapper mapper){this.mapper=mapper;}
 @Transactional(readOnly=true) public User get(long id){return mapper.findById(id);}
 @Transactional(readOnly=true) public List<User> list(Long cursor,int limit){return mapper.findPage(cursor,Math.min(Math.max(limit,1),100));}
 @Transactional public void create(String email,String name){mapper.insert(email,name);}
 @Transactional public boolean rename(long id,String name){return mapper.updateName(id,name)>0;}
 @Transactional public boolean delete(long id){return mapper.softDelete(id)>0;}
}
