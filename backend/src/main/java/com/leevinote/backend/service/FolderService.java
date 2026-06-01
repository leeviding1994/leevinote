package com.leevinote.backend.service;

import com.leevinote.backend.entity.Folder;
import com.leevinote.backend.repository.FolderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class FolderService {
    private final FolderRepository folderRepository;

    public List<Folder> getFoldersByUser(Long userId) {
        return folderRepository.findByUserIdOrderByCreatedAtAsc(userId);
    }

    public Folder createFolder(Folder folder) {
        return folderRepository.save(folder);
    }

    public Folder updateFolder(Long id, Folder updated) {
        Folder folder = folderRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Folder not found: " + id));
        folder.setName(updated.getName());
        folder.setParentId(updated.getParentId());
        return folderRepository.save(folder);
    }

    public void deleteFolder(Long id) {
        folderRepository.deleteById(id);
    }
}