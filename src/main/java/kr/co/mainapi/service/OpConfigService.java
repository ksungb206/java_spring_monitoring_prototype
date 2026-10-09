package kr.co.mainapi.service;
import java.util.List;
import kr.co.mainapi.dto.OpConfig;
import kr.co.mainapi.mapper.OpConfigMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service
public class OpConfigService {
 private final OpConfigMapper mapper;
 public OpConfigService(OpConfigMapper mapper){this.mapper=mapper;}
 @Transactional(readOnly=true) public List<OpConfig> getAll(){return mapper.findAll();}
}
