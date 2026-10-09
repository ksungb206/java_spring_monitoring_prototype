package kr.co.mainapi.mapper;
import java.util.List;
import kr.co.mainapi.dto.User;
import org.apache.ibatis.annotations.Param;
public interface UserMapper {
 User findById(@Param("id") long id);
 List<User> findPage(@Param("lastId") Long lastId,@Param("limit") int limit);
 int insert(@Param("email") String email,@Param("name") String name);
 int updateName(@Param("id") long id,@Param("name") String name);
 int softDelete(@Param("id") long id);
}
